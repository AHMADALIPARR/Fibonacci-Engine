# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Minimal Morphic-style object model implemented in Ruby (it is NOT Squeak or Pharo Morphic and makes
  # no compatibility claim). Every visible object is a Morph with bounds, a fill colour, an owner and an
  # ordered list of submorphs. Morphs draw themselves on a Cairo context, receive mouse/keyboard events
  # routed by the WorldMorph (deepest morph under the pointer first), and receive step(dt) ticks for
  # animation. Morphs are live objects: they can be added, removed, moved and resized at run time.
  module Morphic
    # Morphs are owned by the GTK main thread. Background jobs (ruby/application/gui/jobs.rb) never touch
    # a morph directly from their own thread: TextMorph#content= and Morphic.defer queue the change, and
    # GtkHost drains the queue on the main thread every tick.
    @deferred = Queue.new

    def self.on_main_thread? = Thread.current.equal?(Thread.main)
    def self.defer(&blk) = @deferred.push(blk)

    def self.drain_deferred
      while (blk = @deferred.pop(timeout: 0))
        blk.call
      end
    end

    Color = Struct.new(:r, :g, :b, :a) do
      def self.hex(str, a = 1.0)
        v = str.delete('#').scan(/../).map { |h| h.to_i(16) / 255.0 }
        new(v[0], v[1], v[2], a)
      end
    end

    module Palette
      BG = Color.hex('#1b1f27')
      PANEL = Color.hex('#232936')
      PANEL2 = Color.hex('#2b3242')
      TEXT = Color.hex('#e6e9ef')
      DIM = Color.hex('#9aa3b2')
      ACCENT = Color.hex('#5fb3f9')
      OK = Color.hex('#62d27a')
      BAD = Color.hex('#ff6b6b')
      WARN = Color.hex('#ffcc66')
      BASE = { 'A' => Color.hex('#ff6b6b'), 'C' => Color.hex('#ffcc66'), 'G' => Color.hex('#62d27a'), 'T' => Color.hex('#5fb3f9') }.freeze
    end

    class Morph
      attr_accessor :x, :y, :width, :height, :color, :owner, :visible, :name
      attr_reader :submorphs

      def initialize(x: 0, y: 0, width: 10, height: 10, color: nil, name: nil)
        @x = x
        @y = y
        @width = width
        @height = height
        @color = color
        @submorphs = []
        @owner = nil
        @visible = true
        @name = name
      end

      def add(morph)
        morph.owner&.remove(morph)
        morph.owner = self
        @submorphs << morph
        morph
      end

      def remove(morph)
        @submorphs.delete(morph)
        morph.owner = nil
      end

      def remove_all
        @submorphs.dup.each { |m| remove(m) }
      end

      def world
        o = self
        o = o.owner while o.owner
        o
      end

      def contains?(px, py) = px >= @x && py >= @y && px < @x + @width && py < @y + @height

      def morph_at(px, py)
        return nil unless @visible && contains?(px, py)

        @submorphs.reverse_each do |m|
          hit = m.morph_at(px, py)
          return hit if hit
        end
        self
      end

      def each_morph(&blk)
        blk.call(self)
        @submorphs.each { |m| m.each_morph(&blk) }
      end

      def find(name)
        each_morph { |m| return m if m.name == name }
        nil
      end

      def full_draw(cr)
        return unless @visible

        cr.save
        cr.rectangle(@x, @y, @width, @height)
        cr.clip
        draw(cr)
        @submorphs.each { |m| m.full_draw(cr) }
        cr.restore
      end

      def draw(cr)
        return unless @color

        set_color(cr, @color)
        cr.rectangle(@x, @y, @width, @height)
        cr.fill
      end

      def step(dt)
        @submorphs.each { |m| m.step(dt) if m.visible }
      end

      # Event hooks: return true when handled.
      def mouse_down(_px, _py, _button) = false
      def mouse_up(_px, _py) = false
      def mouse_drag(_dx, _dy) = false
      def scroll(_dir) = false
      def key_press(_text, _keyname) = false
      def wants_keyboard? = false

      def set_color(cr, c) = cr.set_source_rgba(c.r, c.g, c.b, c.a)

      def text(cr, str, px, py, size: 13, color: Palette::TEXT, bold: false, mono: true)
        cr.select_font_face(mono ? 'DejaVu Sans Mono' : 'DejaVu Sans', 0, bold ? 1 : 0)
        cr.set_font_size(size)
        set_color(cr, color)
        cr.move_to(px, py)
        cr.show_text(str.to_s)
      end

      def text_width(cr, str, size: 13, mono: true)
        cr.select_font_face(mono ? 'DejaVu Sans Mono' : 'DejaVu Sans', 0, 0)
        cr.set_font_size(size)
        cr.text_extents(str.to_s).width
      end
    end
  end
end
