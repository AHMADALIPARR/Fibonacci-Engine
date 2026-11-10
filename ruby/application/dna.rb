# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # DNA alphabet mappings.
  #  * Compatibility mode (the JS original's DNA=['A','T']): symbol 0 -> 'A', symbol 1 -> 'T'.
  #  * Two-bit mode (new): documented bijection {0,1}^2 -> {A,C,G,T}, first bit is the high bit:
  #      00 -> A, 01 -> C, 10 -> G, 11 -> T
  module DNA
    COMPAT = %w[A T].freeze
    TWO_BIT = %w[A C G T].freeze

    class EncodingError < ArgumentError; end

    module_function

    def compat_encode(bits)
      bits.map do |b|
        raise EncodingError, "non-binary symbol #{b.inspect}" unless [0, 1].include?(b)

        COMPAT[b]
      end.join
    end

    def compat_decode(str)
      str.chars.map do |c|
        i = COMPAT.index(c)
        raise EncodingError, "base #{c.inspect} is not in the compatibility alphabet A/T" if i.nil?

        i
      end
    end

    # Length policy for odd-length input:
    #   :reject (default) raises EncodingError
    #   :pad_zero appends one 0 bit and reports pad: 1 so decode can strip it
    def encode2(bits, policy: :reject)
      bits.each { |b| raise EncodingError, "non-binary symbol #{b.inspect}" unless [0, 1].include?(b) }
      pad = 0
      if bits.length.odd?
        case policy
        when :reject then raise EncodingError, "odd-length input (#{bits.length} bits) rejected by policy :reject"
        when :pad_zero
          bits += [0]
          pad = 1
        else raise ArgumentError, "unknown policy #{policy.inspect}"
        end
      end
      bases = bits.each_slice(2).map { |hi, lo| TWO_BIT[(hi << 1) | lo] }.join
      { bases: bases, pad: pad }
    end

    def decode2(bases, pad: 0)
      raise EncodingError, 'pad must be 0 or 1' unless [0, 1].include?(pad)

      bits = bases.chars.flat_map do |c|
        i = TWO_BIT.index(c)
        raise EncodingError, "base #{c.inspect} is not in {A,C,G,T}" if i.nil?

        [i >> 1, i & 1]
      end
      if pad == 1
        raise EncodingError, 'pad bit is not zero' unless bits.last.zero?

        bits = bits[0...-1]
      end
      bits
    end

    def complement(bases)
      bases.tr('ACGT', 'TGCA')
    end
  end
end
