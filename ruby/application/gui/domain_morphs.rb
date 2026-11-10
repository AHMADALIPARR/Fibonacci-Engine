# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative '../../morphic/world'
require_relative '../dna'
require_relative '../spiral'

module MorphicHelix
  module Morphic
    # Animated double helix of a DNA string. Strand 1 is the sequence; strand 2 its Watson-Crick
    # complement. Rotation (drag or auto), zoom, strand selection and base-pair highlighting are live.
    class HelixMorph < Morph
      attr_accessor :sequence, :angle, :zoom, :strand_mode, :highlight, :auto_rotate

      def initialize(**kw)
        super(color: Palette::PANEL, **kw)
        @sequence = ''
        @angle = 0.0
        @zoom = 1.0
        @strand_mode = 'both'
        @highlight = nil
        @auto_rotate = true
      end

      def spacing = 22.0 * @zoom
      def radius = 70.0 * @zoom

      def visible_count = [((@width - 60) / spacing).floor, @sequence.length].min

      def step(dt)
        @angle += dt * 0.9 if @auto_rotate
      end

      def mouse_drag(dx, _dy)
        @angle += dx * 0.02
        true
      end

      def mouse_down(px, _py, _button)
        i = ((px - @x - 30) / spacing).round
        @highlight = i if i >= 0 && i < visible_count
        true
      end

      def scroll(dir)
        @zoom = (@zoom * (dir == :up ? 1.1 : 1 / 1.1)).clamp(0.4, 3.0)
        true
      end

      def draw(cr)
        super
        n = visible_count
        cy = @y + @height / 2.0
        text(cr, "DNA helix  n=#{@sequence.length} shown=#{n}  zoom=#{format('%.2f', @zoom)}  strands=#{@strand_mode}", @x + 10, @y + 18, size: 12, color: Palette::DIM)
        pts = (0...n).map do |i|
          ph = @angle + i * (2 * Math::PI / 10.5)
          px = @x + 30 + i * spacing
          [px, cy + radius * Math.sin(ph), cy - radius * Math.sin(ph), Math.cos(ph)]
        end
        # base-pair rungs, back to front
        pts.each_with_index.sort_by { |p, _| p[3] }.each do |(px, y1, y2, depth), i|
          b1 = @sequence[i]
          b2 = MorphicHelix::DNA.complement(b1)
          alpha = 0.35 + 0.65 * (depth + 1) / 2
          mid = (y1 + y2) / 2
          if @strand_mode != 'strand 2'
            c = Palette::BASE.fetch(b1, Palette::DIM)
            cr.set_source_rgba(c.r, c.g, c.b, alpha)
            cr.set_line_width(4 * @zoom)
            cr.move_to(px, y1)
            cr.line_to(px, mid)
            cr.stroke
          end
          if @strand_mode != 'strand 1'
            c = Palette::BASE.fetch(b2, Palette::DIM)
            cr.set_source_rgba(c.r, c.g, c.b, alpha)
            cr.set_line_width(4 * @zoom)
            cr.move_to(px, mid)
            cr.line_to(px, y2)
            cr.stroke
          end
          next unless i == @highlight

          set_color(cr, Palette::TEXT)
          cr.set_line_width(2)
          cr.rectangle(px - 9, [y1, y2].min - 12, 18, (y1 - y2).abs + 24)
          cr.stroke
        end
        # backbones
        [[1, 'strand 1'], [2, 'strand 2']].each do |k, label|
          next if @strand_mode != 'both' && @strand_mode != label

          set_color(cr, k == 1 ? Palette::TEXT : Palette::DIM)
          cr.set_line_width(2.5)
          pts.each_with_index do |p, i|
            yy = k == 1 ? p[1] : p[2]
            i.zero? ? cr.move_to(p[0], yy) : cr.line_to(p[0], yy)
          end
          cr.stroke
        end
        # position labels and base letters
        pts.each_with_index do |(px, y1, y2, _), i|
          text(cr, @sequence[i], px - 4, y1 - 8, size: 11) if @strand_mode != 'strand 2'
          text(cr, MorphicHelix::DNA.complement(@sequence[i]), px - 4, y2 + 16, size: 11, color: Palette::DIM) if @strand_mode != 'strand 1'
          text(cr, i.to_s, px - 6, @y + @height - 8, size: 10, color: Palette::DIM) if (i % 5).zero? || i == @highlight
        end
        return unless @highlight && @highlight < @sequence.length

        b = @sequence[@highlight]
        text(cr, "selected pair ##{@highlight}: #{b}-#{MorphicHelix::DNA.complement(b)}", @x + @width - 260, @y + 18, size: 12, color: Palette::WARN)
      end
    end

    # Rows of bit cells (used for braid lanes, multistrand states, binary representations).
    class BitRowsMorph < Morph
      attr_accessor :rows

      def initialize(**kw)
        super(color: Palette::PANEL2, **kw)
        @rows = []
      end

      def draw(cr)
        super
        cell = 14
        @rows.each_with_index do |(label, bits, col), r|
          py = @y + 8 + r * (cell + 8)
          text(cr, label, @x + 6, py + 11, size: 11, color: Palette::DIM)
          bits.each_with_index do |b, i|
            c = b == 1 ? (col || Palette::ACCENT) : Palette::PANEL
            set_color(cr, c)
            cr.rectangle(@x + 130 + i * (cell + 2), py, cell, cell)
            cr.fill
          end
        end
      end
    end

    # Square-spiral layout view: draws the first N spiral positions with their indices.
    class SpiralMorph < Morph
      attr_accessor :n, :groups, :engine, :selected, :on_pick

      def initialize(engine:, **kw)
        super(color: Palette::PANEL, **kw)
        @engine = engine
        @n = 49
        @groups = []
        @selected = nil
        @on_pick = nil
      end

      def cell = [[(@width - 20) / (2 * ring_max + 1), (@height - 20) / (2 * ring_max + 1)].min, 40].min
      def ring_max = MorphicHelix::Spiral.ring_coord([@n - 1, 0].max)[0]
      def centre = [@x + @width / 2, @y + @height / 2]

      def mouse_down(px, py, _button)
        cx, cy = centre
        gx = ((px - cx) / cell.to_f).round
        gy = -((py - cy) / cell.to_f).round
        k = @engine.unmap(gx, gy)
        @selected = k
        @on_pick&.call(gx, gy, k)
        true
      end

      def draw(cr)
        super
        cx, cy = centre
        c = cell
        pal = [Palette::ACCENT, Palette::OK, Palette::WARN, Palette::BAD, Palette::BASE['C'], Palette::TEXT]
        prev = nil
        (0...@n).each do |i|
          gx, gy = MorphicHelix::Spiral.position(i)
          px = cx + gx * c
          py = cy - gy * c
          ring = MorphicHelix::Spiral.ring_coord(i)[0]
          g = @groups.index { |grp| grp.include?(ring) }
          col = ring.zero? ? Palette::TEXT : pal[(g || 0) % pal.length]
          cr.set_source_rgba(col.r, col.g, col.b, i == @selected ? 1.0 : 0.35)
          cr.rectangle(px - c / 2 + 1, py - c / 2 + 1, c - 2, c - 2)
          cr.fill
          if prev
            set_color(cr, Palette::DIM)
            cr.set_line_width(1)
            cr.move_to(*prev)
            cr.line_to(px, py)
            cr.stroke
          end
          prev = [px, py]
          text(cr, i.to_s, px - c / 2 + 3, py + 4, size: [c / 3, 11].min, color: Palette::BG) if c >= 18
        end
      end
    end

    # Turing-machine tape around the head.
    class TapeMorph < Morph
      attr_accessor :config, :blank

      def initialize(**kw)
        super(color: Palette::PANEL, **kw)
        @config = nil
        @blank = '_'
      end

      def draw(cr)
        super
        return unless @config

        cells = 21
        cw = [(@width - 20) / cells, 44].min
        x0 = @x + (@width - cells * cw) / 2
        (0...cells).each do |k|
          pos = @config.head - cells / 2 + k
          sym = @config.tape.fetch(pos, @blank)
          head = pos == @config.head
          set_color(cr, head ? Palette::WARN : Palette::PANEL2)
          cr.rectangle(x0 + k * cw + 1, @y + 40, cw - 2, cw - 2)
          cr.fill
          text(cr, sym, x0 + k * cw + cw / 2 - 5, @y + 40 + cw / 2 + 6, size: 16, color: head ? Palette::BG : Palette::TEXT, bold: true)
          text(cr, pos.to_s, x0 + k * cw + 4, @y + 40 + cw + 12, size: 9, color: Palette::DIM)
        end
        set_color(cr, Palette::WARN)
        hx = x0 + (cells / 2) * cw + cw / 2
        cr.move_to(hx - 8, @y + 26)
        cr.line_to(hx + 8, @y + 26)
        cr.line_to(hx, @y + 38)
        cr.close_path
        cr.fill
        text(cr, "state=#{@config.state}  head=#{@config.head}  steps=#{@config.steps}", @x + 10, @y + 18, size: 13)
      end
    end
  end
end
