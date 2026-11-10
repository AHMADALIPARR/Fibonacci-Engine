# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Fibonacci word recurrence, ported from fibonacci_braid.js (fibonacciWords).
  #   W0 = A, W1 = AB, W(n+2) = W(n+1) || W(n)
  # Symbols are integers: A = 0, B = 1 (same as the JS constants A=0, B=1).
  module Fibonacci
    A = 0
    B = 1
    JS_MAX_COUNT = 24
    # Explicit bound for the extended generator (not part of the JS original).
    DEFAULT_MAX_LENGTH = 10_000_000

    class BoundError < ArgumentError; end

    module_function

    # Behaviour-equivalent port of fibonacciWords(count): returns W0..W(count-1).
    # The JS original asserts 2 <= count <= 24; this port raises BoundError on the same domain.
    def words(count)
      unless count.is_a?(Integer) && count >= 2 && count <= JS_MAX_COUNT
        raise BoundError, "count must be an integer in 2..#{JS_MAX_COUNT} (JS compatibility bound), got #{count.inspect}"
      end
      generate(count, max_length: nil)
    end

    # Extended generator with an explicit, caller-chosen length bound instead of the fixed count bound.
    def words_bounded(count, max_length: DEFAULT_MAX_LENGTH)
      raise BoundError, "count must be an integer >= 1, got #{count.inspect}" unless count.is_a?(Integer) && count >= 1
      raise BoundError, "requested W#{count - 1} has length #{length(count - 1)} > max_length #{max_length}" if length(count - 1) > max_length

      generate(count, max_length: max_length)
    end

    def generate(count, max_length:)
      ws = [[A], [A, B]]
      (2...count).each { |i| ws << (ws[i - 1] + ws[i - 2]) }
      ws = ws.first(count)
      (2...ws.length).each do |i|
        raise "length recurrence violated at #{i}" unless ws[i].length == ws[i - 1].length + ws[i - 2].length
        raise "prefix property violated at #{i}" unless ws[i][0, ws[i - 1].length] == ws[i - 1]
      end
      raise BoundError, 'max_length exceeded' if max_length && ws.last.length > max_length

      ws
    end
    private_class_method :generate

    # W_n for a single depth n (bounded).
    def word(n, max_length: DEFAULT_MAX_LENGTH)
      words_bounded(n + 1, max_length: max_length).last
    end

    # |W_n| = F(n+2) with F(0)=0, F(1)=1, computed by the length recurrence (no word materialised).
    def length(n)
      raise BoundError, "n must be >= 0" unless n.is_a?(Integer) && n >= 0
      a = 1 # |W0|
      b = 2 # |W1|
      return a if n.zero?

      (n - 1).times { a, b = b, a + b }
      b
    end

    # Fibonacci numbers F(0)=0, F(1)=1.
    def fib(k)
      a = 0
      b = 1
      k.times { a, b = b, a + b }
      a
    end

    # Symbol at position i of W_n, computed by descending the recurrence (O(n), no materialisation).
    def index(n, i)
      raise BoundError, "index #{i} out of range for W#{n} (length #{length(n)})" unless i.is_a?(Integer) && i >= 0 && i < length(n)

      loop do
        return A if n.zero?
        return [A, B][i] if n == 1

        left = length(n - 1)
        if i < left
          n -= 1
        else
          i -= left
          n -= 2
        end
      end
    end

    # Reversible binary conversion: bits (0/1) -> { length:, bytes: } MSB-first, zero padded final byte.
    def pack(bits)
      bits.each { |b| raise ArgumentError, "non-binary symbol #{b.inspect}" unless [0, 1].include?(b) }
      bytes = bits.each_slice(8).map do |chunk|
        chunk += [0] * (8 - chunk.length)
        chunk.reduce(0) { |acc, b| (acc << 1) | b }
      end
      { length: bits.length, bytes: bytes }
    end

    def unpack(packed)
      len = packed.fetch(:length)
      bytes = packed.fetch(:bytes)
      raise ArgumentError, 'byte count does not match length' unless bytes.length == (len + 7) / 8

      bits = bytes.flat_map { |byte| 7.downto(0).map { |k| (byte >> k) & 1 } }
      raise ArgumentError, 'nonzero padding bits' unless bits[len..].all?(&:zero?)

      bits.first(len)
    end

    def to_s01(bits) = bits.join
    def from_s01(str)
      raise ArgumentError, "not a 0/1 string: #{str.inspect}" unless str.match?(/\A[01]*\z/)

      str.chars.map(&:to_i)
    end
  end
end
