# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Two-lane XOR braid, ported from fibonacci_braid.js (braid / unbraid / xor).
  #   B(x, y)      = (y, x XOR y)
  #   B^-1(a, b)   = (a XOR b, a)
  # This is a constructed reversible binary map. It is NOT the Artin braid group.
  module Braid
    class LengthMismatch < ArgumentError; end

    module_function

    def check_bits(v)
      v.each { |b| raise ArgumentError, "non-binary symbol #{b.inspect}" unless [0, 1].include?(b) }
    end

    def xor(a, b)
      raise LengthMismatch, "xor length mismatch #{a.length} != #{b.length}" unless a.length == b.length

      a.each_index.map { |i| a[i] ^ b[i] }
    end

    def braid(x, y)
      raise LengthMismatch, "braid length mismatch #{x.length} != #{y.length}" unless x.length == y.length

      check_bits(x)
      check_bits(y)
      [y.dup, xor(x, y)]
    end

    def unbraid(a, b)
      raise LengthMismatch, "unbraid length mismatch #{a.length} != #{b.length}" unless a.length == b.length

      [xor(a, b), a.dup]
    end

    # Lane y of the original JS main(): y[i] = x[(i + k) mod n] (x rotated left by k). Single definition used by
    # the GUI and the tests.
    def rotate(x, k)
      x.each_index.map { |i| x[(i + k) % x.length] }
    end

    # Explicit unequal-length policy (never silent truncation): the shorter lane is zero-extended to
    # the longer length and the original lengths are carried in the result so the inverse restores both
    # lanes exactly.
    def braid_padded(x, y)
      n = [x.length, y.length].max
      a, b = braid(x + [0] * (n - x.length), y + [0] * (n - y.length))
      { a: a, b: b, x_length: x.length, y_length: y.length }
    end

    def unbraid_padded(rec)
      x, y = unbraid(rec.fetch(:a), rec.fetch(:b))
      xl = rec.fetch(:x_length)
      yl = rec.fetch(:y_length)
      raise ArgumentError, 'padding bits of x are not zero' unless x[xl..].all?(&:zero?)
      raise ArgumentError, 'padding bits of y are not zero' unless y[yl..].all?(&:zero?)

      [x.first(xl), y.first(yl)]
    end
  end
end
