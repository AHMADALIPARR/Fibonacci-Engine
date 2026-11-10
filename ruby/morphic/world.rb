# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'widgets'

module MorphicHelix
  module Morphic
    # Root of the morph tree. Owns keyboard focus, drag state, the step loop and event routing.
    class WorldMorph < Morph
      attr_accessor :focus, :drag_target, :on_change
      attr_reader :event_log

      def initialize(width:, height:)
        super(x: 0, y: 0, width: width, height: height, color: Palette::BG, name: 'world')
        @focus = nil
        @drag_target = nil
        @last = nil
        @event_log = []
      end

      def dispatch_mouse_down(px, py, button = 1)
        target = morph_at(px, py)
        @focus = nil unless target&.wants_keyboard?
        @last = [px, py]
        m = target
        while m
          if m.mouse_down(px, py, button)
            @event_log << { event: 'mouse_down', x: px, y: py, morph: m.class.name.split('::').last, name: m.name }
            @drag_target ||= m
            return m
          end
          m = m.owner
        end
        nil
      end

      def dispatch_motion(px, py)
        return unless @drag_target && @last

        dx = px - @last[0]
        dy = py - @last[1]
        @last = [px, py]
        if @drag_target.respond_to?(:drag_to)
          @drag_target.drag_to(px)
        else
          @drag_target.mouse_drag(dx, dy)
        end
      end

      def dispatch_mouse_up(px, py)
        @drag_target&.mouse_up(px, py)
        @drag_target = nil
        @last = nil
      end

      def dispatch_scroll(px, py, dir)
        m = morph_at(px, py)
        while m
          return if m.scroll(dir)

          m = m.owner
        end
      end

      def dispatch_key(text, keyname)
        @focus&.key_press(text, keyname)
      end

      # Simulated click on a named morph: routes a real mouse_down at the morph's centre through the
      # same dispatch path as a pointer click (used by --actions for unattended GUI runs).
      def click(name)
        m = find(name) or raise ArgumentError, "no morph named #{name}"
        dispatch_mouse_down(m.x + m.width / 2, m.y + m.height / 2)
        dispatch_mouse_up(m.x + m.width / 2, m.y + m.height / 2)
      end
    end

    # GTK 3 host window: provides the Cairo surface, raw input events and a ~30 Hz step timer.
    # Closing:
    #   * the window manager's close button (WM_DELETE_WINDOW / delete-event),
    #   * Ctrl+Q, and Escape when no text field has keyboard focus (Escape in a text field only releases focus),
    #   * SIGTERM / SIGINT / SIGHUP (the trap only sets a flag; the tick performs the close on the main thread).
    # Every path goes through on_close (the application's shutdown: stop background jobs and terminate child
    # processes) and then ends the GTK main loop. Ctrl+W calls on_close_panel (closes the current panel).
    class GtkHost
      attr_accessor :on_close, :on_close_panel

      def initialize(world, title:)
        require 'gtk3'
        @world = world
        @closing = false
        @signal_close = false
        @window = Gtk::Window.new(title)
        @window.set_default_size(world.width, world.height)
        @area = Gtk::DrawingArea.new
        @area.can_focus = true
        @area.add_events(%i[button_press_mask button_release_mask pointer_motion_mask scroll_mask key_press_mask])
        @area.signal_connect('draw') do |_w, cr|
          @world.full_draw(cr)
          true
        end
        @area.signal_connect('button-press-event') do |_w, e|
          @area.grab_focus
          @world.dispatch_mouse_down(e.x, e.y, e.button)
          @area.queue_draw
          true
        end
        @area.signal_connect('button-release-event') { |_w, e| @world.dispatch_mouse_up(e.x, e.y); true }
        @area.signal_connect('motion-notify-event') { |_w, e| @world.dispatch_motion(e.x, e.y); true }
        @area.signal_connect('scroll-event') do |_w, e|
          dir = e.direction == Gdk::ScrollDirection::DOWN ? :down : :up
          @world.dispatch_scroll(e.x, e.y, dir)
          true
        end
        # Window-level shortcuts first; everything else goes to the focused text morph.
        @window.signal_connect('key-press-event') do |_w, e|
          text = Gdk::Keyval.to_unicode(e.keyval).chr(Encoding::UTF_8).then { |c| c == "\u0000" ? '' : c }
          handle_key(Gdk::Keyval.to_name(e.keyval), e.state.control_mask?, text)
          true
        end
        @window.add(@area)
        @window.signal_connect('delete-event') do
          shutdown
          false # let GTK destroy the window
        end
        @window.signal_connect('destroy') { Gtk.main_quit }
        %w[TERM INT HUP].each { |sig| Signal.trap(sig) { @signal_close = true } }
        @last = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        GLib::Timeout.add(33) do
          if @signal_close
            request_close
            next false
          end
          Morphic.drain_deferred
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @world.step(now - @last)
          @last = now
          @area.queue_draw
          true
        end
      end

      def handle_key(name, ctrl, text)
        if ctrl && %w[q Q].include?(name)
          request_close
        elsif ctrl && %w[w W].include?(name)
          @on_close_panel&.call
        elsif name == 'Escape'
          if @world.focus then @world.focus = nil else request_close end
        else
          @world.dispatch_key(text, name)
        end
        @area.queue_draw unless @closing
      end

      # Same path as the window manager's close button: emits delete-event, then destroy.
      def request_close
        return if @closing

        @window.close
      end

      def shutdown
        return if @closing

        @closing = true
        @on_close&.call
      end

      def after(ms, &blk)
        GLib::Timeout.add(ms) do
          blk.call unless @closing
          @area.queue_draw unless @closing
          false
        end
      end

      def run
        @window.show_all
        @area.grab_focus
        Gtk.main
        shutdown # main loop ended without delete-event (e.g. Gtk.main_quit elsewhere): still clean up
      end

      # Scripted key press through the same handler as the keyboard (used by --actions key:...).
      def send_key(spec)
        parts = spec.split('+')
        name = parts.pop
        ctrl = parts.map(&:downcase).include?('ctrl')
        handle_key(name, ctrl, '')
      end

      def quit = request_close
    end
  end
end
