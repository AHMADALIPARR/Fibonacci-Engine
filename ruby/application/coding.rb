# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'braid'
require_relative 'fibonacci'

module MorphicHelix
  # Binary coding-theory utilities.
  # The fourfold repetition code (ported from encodeDoublyEven/decodeDoublyEven) is the trivial
  # construction 0 -> 0000, 1 -> 1111. The extended Hamming [8,4,4] code is included as a second,
  # classical (not newly discovered) explicitly constructed doubly-even code.
  module Coding
    class DecodeError < ArgumentError; end

    module_function

    def encode_rep4(bits)
      bits.flat_map do |b|
        raise ArgumentError, "non-binary symbol #{b.inspect}" unless [0, 1].include?(b)

        [b] * 4
      end
    end

    # Strict decoder, same behaviour as the JS decodeDoublyEven: rejects any non-codeword block.
    def decode_rep4(code)
      raise DecodeError, 'code length is not a multiple of 4' unless (code.length % 4).zero?

      code.each_slice(4).map do |blk|
        raise DecodeError, "block #{blk.join} is not a codeword" unless blk.uniq.length == 1 && [0, 1].include?(blk[0])

        blk[0]
      end
    end

    # Nearest-codeword decoder (new, not in the JS original). Minimum distance 4 guarantees correction of
    # any single bit error per block; a 2-2 tie (two errors) is detected and reported, not guessed.
    def correct_rep4(code)
      raise DecodeError, 'code length is not a multiple of 4' unless (code.length % 4).zero?

      code.each_slice(4).each_with_index.map do |blk, i|
        ones = blk.sum
        if ones >= 3 then 1
        elsif ones <= 1 then 0
        else raise DecodeError, "block #{i} (#{blk.join}) is equidistant from 0000 and 1111: error detected, not correctable"
        end
      end
    end

    def weight(v) = v.sum
    def distance(a, b) = Braid.xor(a, b).sum
    def distance_matrix(rows) = rows.map { |r| rows.map { |s| distance(r, s) } }

    # Span of a generator matrix over GF(2); message m (MSB-first index) -> codeword.
    def span(generator)
      k = generator.length
      n = generator.first.length
      (0...(1 << k)).map do |m|
        bits = (0...k).map { |j| (m >> (k - 1 - j)) & 1 }
        (0...n).map { |c| (0...k).sum { |j| bits[j] * generator[j][c] } % 2 }
      end
    end

    EXT_HAMMING_8_4_G = [
      [1, 0, 0, 0, 0, 1, 1, 1],
      [0, 1, 0, 0, 1, 0, 1, 1],
      [0, 0, 1, 0, 1, 1, 0, 1],
      [0, 0, 0, 1, 1, 1, 1, 0]
    ].freeze

    def member?(code, x) = code.include?(x)

    # Returns { closed: true } or the first counterexample (lexicographic i, j) with x_i XOR x_j not in C.
    def xor_closure(code)
      set = code.to_h { |w| [w, true] }
      code.each_with_index do |a, i|
        code.each_with_index do |b, j|
          z = Braid.xor(a, b)
          return { closed: false, i: i, j: j, x: a, y: b, xor: z } unless set.key?(z)
        end
      end
      { closed: true }
    end

    def doubly_even(code)
      code.each_with_index do |w, i|
        return { doubly_even: false, i: i, word: w, weight: w.sum } unless (w.sum % 4).zero?
      end
      { doubly_even: true }
    end

    def min_distance(code)
      ds = []
      code.each_with_index { |a, i| code.each_with_index { |b, j| ds << distance(a, b) if i < j } }
      ds.min
    end

    # Candidate "code" formed from the distinct length-w windows of a Fibonacci word. This is used to show
    # with counterexamples that such windows are NOT, in general, XOR-closed or doubly even.
    def fibonacci_windows(n, w)
      word = Fibonacci.word(n)
      (0..(word.length - w)).map { |i| word[i, w] }.uniq.sort
    end
  end
end
