# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'morph'

module MorphicHelix
  module Morphic
    # Single-line label.
    class StringMorph < Morph
      attr_accessor :string, :size, :text_color, :bold

      def initialize(string = '', size: 13, color: Palette::TEXT, bold: false, **kw)
        super(height: size + 8, **kw)
        @string = string
        @size = size
        @text_color = color
        @bold = bold
      end

      def draw(cr)
        super
        text(cr, @string, @x + 2, @y + @size + 1, size: @size, color: @text_color, bold: @bold)
      end
    end

    # Multi-line read-only text with vertical scrolling (mouse wheel) and optional per-line colours.
    class TextMorph < Morph
      attr_accessor :lines, :size, :offset

      def initialize(lines = [], size: 12, **kw)
        super(color: Palette::PANEL2, **kw)
        @lines = lines
        @size = size
        @offset = 0
      end

      def content=(value)
        return Morphic.defer { self.content = value } unless Morphic.on_main_thread?

        @lines = value.is_a?(Array) ? value : value.to_s.lines.map(&:chomp)
        @offset = 0
      end

      def scroll(dir)
        visible_lines = ((@height - 8) / (@size + 4)).floor
        @offset = (@offset + (dir == :down ? 3 : -3)).clamp(0, [@lines.length - visible_lines, 0].max)
        true
      end

      def draw(cr)
        super
        lh = @size + 4
        @lines.drop(@offset).each_with_index do |line, i|
          py = @y + 4 + (i + 1) * lh - 4
          break if py > @y + @height

          str, col = line.is_a?(Array) ? line : [line, Palette::TEXT]
          text(cr, str, @x + 6, py, size: @size, color: col)
        end
      end
    end

    class ButtonMorph < Morph
      attr_accessor :label, :action, :enabled, :clicks

      def initialize(label, action = nil, **kw)
        super(height: 26, color: Palette::ACCENT, **kw)
        @label = label
        @action = action
        @enabled = true
        @flash = 0.0
        @clicks = 0
      end

      def mouse_down(_px, _py, _button)
        return false unless @enabled

        @flash = 0.25
        @clicks += 1
        @action&.call
        true
      end

      def step(dt)
        @flash = [@flash - dt, 0.0].max
      end

      def draw(cr)
        c = @enabled ? (@flash.positive? ? Palette::WARN : @color) : Palette::DIM
        set_color(cr, c)
        cr.rectangle(@x, @y, @width, @height)
        cr.fill
        tw = text_width(cr, @label, size: 12)
        text(cr, @label, @x + (@width - tw) / 2, @y + 17, size: 12, color: Palette::BG, bold: true)
      end
    end

    # Horizontal integer slider.
    class SliderMorph < Morph
      attr_reader :value
      attr_accessor :on_change, :min, :max

      def initialize(min:, max:, value:, on_change: nil, **kw)
        super(height: 22, color: Palette::PANEL2, **kw)
        @min = min
        @max = max
        @value = value
        @on_change = on_change
      end

      def value=(v)
        nv = v.clamp(@min, @max)
        changed = nv != @value
        @value = nv
        @on_change&.call(@value) if changed
      end

      def mouse_down(px, _py, _button)
        frac = ((px - @x - 6).to_f / (@width - 12)).clamp(0.0, 1.0)
        self.value = (@min + (frac * (@max - @min))).round
        world.drag_target = self if world.respond_to?(:drag_target=)
        true
      end

      def drag_to(px)
        frac = ((px - @x - 6).to_f / (@width - 12)).clamp(0.0, 1.0)
        self.value = (@min + (frac * (@max - @min))).round
      end

      def draw(cr)
        super
        set_color(cr, Palette::DIM)
        cr.rectangle(@x + 6, @y + @height / 2 - 1, @width - 12, 2)
        cr.fill
        frac = @max == @min ? 0 : (@value - @min).to_f / (@max - @min)
        set_color(cr, Palette::ACCENT)
        cr.arc(@x + 6 + frac * (@width - 12), @y + @height / 2, 7, 0, 2 * Math::PI)
        cr.fill
      end
    end

    # Cycles through a fixed list of options on click.
    class ChoiceMorph < Morph
      attr_reader :index
      attr_accessor :options, :on_change

      def initialize(options, index: 0, on_change: nil, **kw)
        super(height: 26, color: Palette::PANEL2, **kw)
        @options = options
        @index = index
        @on_change = on_change
      end

      def selected = @options[@index]

      def mouse_down(_px, _py, _button)
        @index = (@index + 1) % @options.length
        @on_change&.call(selected)
        true
      end

      def select(value)
        i = @options.index(value) or raise ArgumentError, "unknown option #{value}"
        @index = i
        @on_change&.call(selected)
      end

      def draw(cr)
        super
        set_color(cr, Palette::ACCENT)
        cr.rectangle(@x, @y, @width, @height)
        cr.stroke
        text(cr, "▸ #{selected}", @x + 8, @y + 18, size: 12)
      end
    end

    # Editable one-line text field (keyboard focus by click).
    class TextFieldMorph < Morph
      attr_accessor :string, :on_submit, :allowed

      def initialize(string = '', allowed: nil, on_submit: nil, **kw)
        super(height: 26, color: Palette::PANEL2, **kw)
        @string = +string
        @allowed = allowed
        @on_submit = on_submit
      end

      def wants_keyboard? = true

      def mouse_down(_px, _py, _button)
        world.focus = self if world.respond_to?(:focus=)
        true
      end

      def key_press(text, keyname)
        case keyname
        when 'BackSpace' then @string = @string[0...-1]
        when 'Return', 'KP_Enter' then @on_submit&.call(@string)
        else
          return false if text.nil? || text.empty?
          return true if @allowed && !text.match?(@allowed)

          @string << text
        end
        true
      end

      def draw(cr)
        super
        focused = world.respond_to?(:focus) && world.focus.equal?(self)
        set_color(cr, focused ? Palette::WARN : Palette::DIM)
        cr.rectangle(@x + 0.5, @y + 0.5, @width - 1, @height - 1)
        cr.stroke
        text(cr, @string + (focused ? '▏' : ''), @x + 6, @y + 18, size: 12)
      end
    end

    # Selectable list of strings.
    class ListMorph < Morph
      attr_accessor :items, :selected, :on_select, :offset

      def initialize(items = [], on_select: nil, size: 12, **kw)
        super(color: Palette::PANEL2, **kw)
        @items = items
        @selected = nil
        @on_select = on_select
        @size = size
        @offset = 0
      end

      def line_height = @size + 6

      def mouse_down(_px, py, _button)
        i = ((py - @y - 2) / line_height).floor + @offset
        return true unless i >= 0 && i < @items.length

        @selected = i
        @on_select&.call(i, @items[i])
        true
      end

      def scroll(dir)
        vis = (@height / line_height).floor
        @offset = (@offset + (dir == :down ? 3 : -3)).clamp(0, [@items.length - vis, 0].max)
        true
      end

      def draw(cr)
        super
        @items.drop(@offset).each_with_index do |item, k|
          i = k + @offset
          py = @y + 2 + k * line_height
          break if py > @y + @height

          if i == @selected
            set_color(cr, Palette::ACCENT)
            cr.rectangle(@x, py, @width, line_height)
            cr.fill
          end
          str, col = item.is_a?(Array) ? item : [item, Palette::TEXT]
          text(cr, str, @x + 6, py + @size + 1, size: @size, color: i == @selected ? Palette::BG : col)
        end
      end
    end
  end
end
