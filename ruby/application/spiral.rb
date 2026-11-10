# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'fibonacci'

module MorphicHelix
  # Deterministic square-spiral (Ulam) indexing on the integer lattice Z^2.
  #   index 0 -> (0,0). Ring r >= 1 holds indices (2r-1)^2 ... (2r+1)^2 - 1 (8r cells), split into four
  #   sides s = 0..3 of 2r cells each, offset t in 0...2r:
  #     s=0: ( r,      -r+1+t)   s=1: ( r-1-t,  r)
  #     s=2: (-r,       r-1-t)   s=3: (-r+1+t, -r)
  # This is pure index arithmetic for data layout. It is not a model of gravitation or black holes.
  class Spiral
    attr_reader :history

    def initialize
      @history = []
    end

    def self.isqrt(k)
      raise ArgumentError, 'negative' if k.negative?

      Integer.sqrt(k)
    end

    # Ring decomposition of an index: [r, s, t] (r = 0 means the origin).
    def self.ring_coord(k)
      raise ArgumentError, "index must be a nonnegative integer: #{k.inspect}" unless k.is_a?(Integer) && k >= 0
      return [0, 0, 0] if k.zero?

      m = isqrt(k)
      r = (m + 1) / 2
      off = k - ((2 * r) - 1)**2
      [r, off / (2 * r), off % (2 * r)]
    end

    def self.position(k)
      r, s, t = ring_coord(k)
      return [0, 0] if r.zero?

      case s
      when 0 then [r, -r + 1 + t]
      when 1 then [r - 1 - t, r]
      when 2 then [-r, r - 1 - t]
      else [-r + 1 + t, -r]
      end
    end

    def self.index(x, y)
      r = [x.abs, y.abs].max
      return 0 if r.zero?

      s, t = if x == r && y > -r then [0, y + r - 1]
             elsif y == r then [1, r - 1 - x]
             elsif x == -r then [2, r - 1 - y]
             else [3, x + r - 1]
             end
      (((2 * r) - 1)**2) + (s * 2 * r) + t
    end

    # Verifies the bijection {0..N-1} -> first N spiral positions: positions distinct and index(position(i)) = i.
    def self.verify_bijection(n)
      seen = {}
      (0...n).each do |i|
        p = position(i)
        return { ok: false, reason: "position #{p.inspect} repeated (#{seen[p]} and #{i})" } if seen.key?(p)
        return { ok: false, reason: "index(position(#{i})) = #{index(*p)}" } unless index(*p) == i

        seen[p] = i
      end
      { ok: true, n: n }
    end

    # 3-D layout of an s x s x d array, s odd: linear index i -> (x, y, z) with z = i div s^2 and (x, y) the
    # spiral position of i mod s^2. For odd s = 2R+1 the first s^2 spiral positions fill exactly [-R, R]^2.
    def self.position3(i, side)
      raise ArgumentError, 'side must be odd and positive' unless side.is_a?(Integer) && side.positive? && side.odd?

      z, rem = i.divmod(side * side)
      x, y = position(rem)
      [x, y, z]
    end

    def self.index3(x, y, z, side)
      raise ArgumentError, 'side must be odd and positive' unless side.positive? && side.odd?
      r = (side - 1) / 2
      raise ArgumentError, 'point outside the s x s layer' unless x.abs <= r && y.abs <= r && z >= 0

      (z * side * side) + index(x, y)
    end

    # Fibonacci radial grouping (scheduling parameter): rings 1, 2, 3, ... are batched into consecutive
    # groups of sizes F(2), F(3), F(4), ... = 1, 2, 3, 5, 8, ... Returns arrays of ring numbers.
    def self.fibonacci_ring_groups(max_ring)
      groups = []
      ring = 1
      k = 2
      while ring <= max_ring
        size = Fibonacci.fib(k)
        groups << (ring...[ring + size, max_ring + 1].min).to_a
        ring += size
        k += 1
      end
      groups
    end

    # Recorded mapping for GUI history.
    def map(k)
      p = self.class.position(k)
      @history << { op: 'position', index: k, ring: self.class.ring_coord(k), position: p }
      p
    end

    def unmap(x, y)
      k = self.class.index(x, y)
      @history << { op: 'index', position: [x, y], index: k }
      k
    end
  end
end
