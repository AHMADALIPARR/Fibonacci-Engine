# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# MORPHIC HELIX graphical workspace (Ruby + GTK 3 + the Morphic-style object model in ruby/morphic).
#   ruby ruby/application/morphic_helix.rb [--panel NAME] [--actions LIST] [--dump-state FILE] [--quit-after MS]
# --actions is a comma-separated list executed in order after start-up:
#   click:<morph-name>   real mouse_down routed through the world at the morph's centre
#   set:<slider>=<int>   sets a slider value (fires its on_change)
#   type:<field>=<text>  replaces a text field's contents
#   choose:<choice>=<v>  selects an option of a choice morph
#   tab:<panel>          switches panel (same as clicking its tab)
#   wait:<ms>            pause before the next action
#   close:<panel>        closes a panel (same as clicking the × on its tab)
#   key:<keyname>        window-level key (Escape, ctrl+q, ctrl+w), same path as the keyboard
# Each action starts only after the background jobs started by the previous action have finished.
# Closing: window close button, Ctrl+Q, Escape (when no text field is focused), SIGTERM/SIGINT/SIGHUP.
# Ctrl+W or the × on a tab closes that panel; closing the last panel closes the window. On every close
# path the running background jobs are cancelled and their child processes are terminated.
require_relative '../morphic/world'
require_relative 'gui/panels'

module MorphicHelix
  class App
    W = 1400
    H = 900
    TAB_W = 164
    TABS = [%w[fibonacci Fibonacci], %w[helix DNA\ Helix], %w[cbqn CBQN\ Console], %w[elf Elf\ Inspector], %w[agda Agda\ Proofs],
            %w[turing Turing\ Machine], %w[spiral Spiral], %w[capacity Capacity]].freeze

    attr_reader :world, :current

    def initialize
      @world = Morphic::WorldMorph.new(width: W, height: H)
      @state = GUI::State.new
      @panels = {
        'fibonacci' => GUI::FibonacciPanel.new(@state, W, H), 'helix' => GUI::HelixPanel.new(@state, W, H),
        'cbqn' => GUI::CBQNPanel.new(@state, W, H), 'elf' => GUI::ElfPanel.new(W, H), 'agda' => GUI::AgdaPanel.new(W, H),
        'turing' => GUI::TuringPanel.new(W, H), 'spiral' => GUI::SpiralPanel.new(W, H), 'capacity' => GUI::CapacityPanel.new(W, H)
      }
      @open = TABS.map(&:first)
      @panels.each_value { |p| @world.add(p) }
      @tabs = {}
      TABS.each do |key, label|
        tab = Morphic::ButtonMorph.new(label, -> { show(key) }, y: 8, width: TAB_W - 24, name: "tab-#{key}")
        close = Morphic::ButtonMorph.new('×', -> { close_panel(key) }, y: 8, width: 22, name: "close-#{key}")
        @world.add(tab)
        @world.add(close)
        @tabs[key] = [tab, close]
      end
      layout_tabs
      show('fibonacci')
    end

    def layout_tabs
      @open.each_with_index do |key, i|
        tab, close = @tabs[key]
        tab.x = 8 + i * 172
        close.x = tab.x + TAB_W - 22
      end
    end

    def show(key)
      raise ArgumentError, "no open panel #{key}" unless @open.include?(key)

      @panels.each { |k, p| p.visible = (k == key) }
      @current = key
      @tabs.each { |k, (tab, _)| tab.color = k == key ? Morphic::Palette::WARN : Morphic::Palette::ACCENT }
    end

    # Closes one panel: cancels its running job (terminating its child processes) and removes the panel and
    # its tab from the world. Closing the last open panel closes the window.
    def close_panel(key = @current)
      return unless @open.include?(key)

      GUI::Jobs.cancel(@panels[key].name)
      @world.remove(@panels[key])
      @tabs[key].each { |m| @world.remove(m) }
      @world.focus = nil if @world.focus && @world.focus.world != @world
      @open.delete(key)
      $stdout.puts "panel closed: #{key}"
      $stdout.flush
      if @open.empty?
        @current = nil
        @host ? @host.request_close : shutdown
      else
        layout_tabs
        show(@open.include?(@current) ? @current : @open.first)
      end
    end

    def open_panels = @open.dup

    # Stops every background job and terminates every child process group. Idempotent.
    def shutdown
      return if @shut

      @shut = true
      GUI::Jobs.cancel_all
    end

    def perform(action)
      kind, arg = action.split(':', 2)
      case kind
      when 'click' then @world.click(arg)
      when 'tab' then @world.click("tab-#{arg}")
      when 'close' then @world.click("close-#{arg}")
      when 'key'
        raise ArgumentError, 'key: needs the GTK host' unless @host

        @host.send_key(arg)
      when 'set'
        n, v = arg.split('=', 2)
        (@world.find(n) or raise ArgumentError, "no morph named #{n}").value = Integer(v)
      when 'type'
        n, v = arg.split('=', 2)
        (@world.find(n) or raise ArgumentError, "no morph named #{n}").string = +v
      when 'choose'
        n, v = arg.split('=', 2)
        (@world.find(n) or raise ArgumentError, "no morph named #{n}").select(v)
      when 'wait' then nil
      else raise ArgumentError, "unknown action #{action}"
      end
    end

    def dump_state(path)
      texts = {}
      @panels[@current]&.each_morph { |m| texts[m.name] = m.lines.map { |l| l.is_a?(Array) ? l[0] : l } if m.is_a?(Morphic::TextMorph) && m.name }
      File.write(path, JSON.pretty_generate({ panel: @current, open_panels: @open, text_morphs: texts, events: @world.event_log }))
    end

    # Runs the scripted actions one after another; each waits until no background job is running.
    def run_script(actions, dump, done_at)
      step = lambda do |rest|
        unless GUI::Jobs.idle?
          @host.after(100) { step.call(rest) }
          next
        end
        if rest.empty?
          if dump
            @host.after(600) do
              dump_state(dump)
              $stdout.puts "state dumped: #{dump}"
              $stdout.flush
            end
          end
          next
        end
        act, *tail = rest
        pause = act.start_with?('wait:') ? Integer(act.split(':', 2)[1]) : 150
        @host.after(pause) do
          perform(act)
          $stdout.puts "action done: #{act}"
          $stdout.flush
          step.call(tail)
        end
      end
      @host.after(done_at) { step.call(actions) }
    end

    def run(argv)
      opts = { actions: [] }
      until argv.empty?
        case (a = argv.shift)
        when '--panel' then opts[:panel] = argv.shift
        when '--actions' then opts[:actions] = argv.shift.split(',')
        when '--dump-state' then opts[:dump] = argv.shift
        when '--quit-after' then opts[:quit] = Integer(argv.shift)
        else raise ArgumentError, "unknown option #{a}"
        end
      end
      @host = Morphic::GtkHost.new(@world, title: 'MORPHIC HELIX')
      @host.on_close = -> { shutdown }
      @host.on_close_panel = -> { close_panel }
      show(opts[:panel]) if opts[:panel]
      run_script(opts[:actions], opts[:dump], 400) if opts[:actions].any? || opts[:dump]
      @host.after(opts[:quit]) { @host.request_close } if opts[:quit]
      at_exit { shutdown }
      @host.run
    end
  end
end

MorphicHelix::App.new.run(ARGV.dup) if $PROGRAM_NAME == __FILE__
