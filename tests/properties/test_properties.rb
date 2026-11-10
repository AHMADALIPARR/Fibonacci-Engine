# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Seeded randomized and exhaustive property tests of the Ruby implementation. These are bounded checks;
# the universal statements are the Agda theorems named in each comment.
require 'minitest/autorun'
%w[fibonacci dna braid multistrand coding turing spiral arrays].each { |f| require_relative "../../ruby/application/#{f}" }

class PropertyTest < Minitest::Test
  include MorphicHelix
  SEED = 7_331

  def rng = (@rng ||= Random.new(SEED))
  def bits(n) = Array.new(n) { rng.rand(2) }
  def all_bits(n) = (0...(1 << n)).map { |m| (0...n).map { |i| (m >> (n - 1 - i)) & 1 } }

  # Invariant A (Agda: invariantA / length-fib)
  def test_fibonacci_lengths
    w = Fibonacci.words(24)
    (2...w.length).each { |k| assert_equal w[k - 1] + w[k - 2], w[k] }
    w.each_with_index { |x, k| assert_equal Fibonacci.fib(k + 2), x.length }
  end

  # Invariant B (Agda: invariantB, braid-unbraid, braid-order3, not-involution)
  def test_braid_inverse_random
    500.times do
      n = rng.rand(0..64)
      x = bits(n)
      y = bits(n)
      assert_equal [x, y], Braid.unbraid(*Braid.braid(x, y))
      assert_equal [x, y], Braid.braid(*Braid.unbraid(x, y))
      assert_equal [x, y], Braid.braid(*Braid.braid(*Braid.braid(x, y)))
    end
    assert_raises(Braid::LengthMismatch) { Braid.braid([1, 0], [1]) }
    rec = Braid.braid_padded([1, 0, 1], [1])
    assert_equal [[1, 0, 1], [1]], Braid.unbraid_padded(rec)
  end

  def test_braid_not_involution
    x = [1]
    y = [1]
    refute_equal [x, y], Braid.braid(*Braid.braid(x, y))
  end

  # Multi-strand programs are bijections; inverse_program undoes run.
  def test_multistrand_inverse_random
    200.times do
      k = rng.rand(2..6)
      n = rng.rand(1..16)
      st = Array.new(k) { bits(n) }
      prog = Array.new(rng.rand(1..10)) do
        case rng.rand(4)
        when 0 then Multistrand.permute((0...k).to_a.shuffle(random: rng))
        when 1 then s, d = (0...k).to_a.sample(2, random: rng); Multistrand.xormix(s, d)
        when 2 then Multistrand.sigma(rng.rand(k - 1))
        else Multistrand.sigma_inv(rng.rand(k - 1))
        end
      end
      fwd = Multistrand.run(prog, st)[:state]
      assert_equal st, Multistrand.run(Multistrand.inverse_program(prog), fwd)[:state]
      assert_equal st, Multistrand.deserialize(Multistrand.serialize(st))
    end
  end

  # The multistrand Sigma operators are NOT Artin braid generators: the braid relation fails on (0,0,1).
  def test_sigma_violates_braid_relation
    st = [[0], [0], [1]]
    l = Multistrand.run(%w[S:0 S:1 S:0].map { |t| Multistrand.parse_op(t) }, st)[:state]
    r = Multistrand.run(%w[S:1 S:0 S:1].map { |t| Multistrand.parse_op(t) }, st)[:state]
    assert_equal [[1], [1], [1]], l
    assert_equal [[1], [1], [0]], r
  end

  # Invariant C (Agda: invariantC, encodeBits-sound/complete)
  def test_dna_roundtrip_exhaustive
    (0..10).step(2).each { |n| all_bits(n).each { |b| assert_equal b, DNA.decode2(DNA.encode2(b)[:bases]) } }
    assert_raises(DNA::EncodingError) { DNA.encode2([1, 0, 1]) }
    r = DNA.encode2([1, 0, 1], policy: :pad_zero)
    assert_equal [1, 0, 1], DNA.decode2(r[:bases], pad: r[:pad])
    all_bits(8).each { |b| assert_equal b, DNA.compat_decode(DNA.compat_encode(b)) }
  end

  # Invariant D (Agda: xor-closed, doubly-even, min-distance-4, corrects-single-error, detects-double-error)
  # This also checks the README erratum: rep4 DOES correct every single-bit error per block.
  def test_rep4_code_exhaustive
    (0..6).each do |n|
      code = all_bits(n).map { |m| Coding.encode_rep4(m) }
      assert Coding.xor_closure(code)[:closed]
      assert Coding.doubly_even(code)[:doubly_even]
      assert_equal 4, Coding.min_distance(code) if n.positive?
      all_bits(n).each do |m|
        c = Coding.encode_rep4(m)
        assert_equal m, Coding.decode_rep4(c)
        c.each_index do |i|
          e = c.dup
          e[i] ^= 1
          assert_equal m, Coding.correct_rep4(e), 'single error corrected'
          assert_raises(Coding::DecodeError) { Coding.decode_rep4(e) } # the original strict decoder rejects
          c.each_index do |j|
            next unless j / 4 == i / 4 && j > i

            e2 = e.dup
            e2[j] ^= 1
            assert_raises(Coding::DecodeError) { Coding.correct_rep4(e2) } # double error in a block: detected
          end
        end
      end
    end
  end

  def test_extended_hamming
    code = Coding.span(Coding::EXT_HAMMING_8_4_G)
    assert_equal 16, code.uniq.length
    assert Coding.xor_closure(code)[:closed]
    assert Coding.doubly_even(code)[:doubly_even]
    assert_equal 4, Coding.min_distance(code)
  end

  def test_fibonacci_windows_counterexample
    win = Coding.fibonacci_windows(6, 4)
    refute Coding.xor_closure(win)[:closed]
    refute Coding.doubly_even(win)[:doubly_even]
  end

  # Invariants E/F (Agda: step-deterministic, runTrace-legal, invariantF)
  def test_turing_traces
    300.times do
      inp = bits(rng.rand(0..12)).join
      r = Turing.run(initial: inp, start: 'scan', rules: Turing::INCREMENT_RULES)
      assert_equal 'HALT', r[:status]
      assert Turing.legal_trace?(r[:configs], rules: Turing::INCREMENT_RULES)
      expect = inp.empty? ? '1' : (inp.to_i(2) + 1).to_s(2).rjust(inp.length, '0')
      assert_equal expect, Turing.get_tape(r[:tape])
      r[:trace].reverse.zip(r[:configs].reverse.drop(1)).reduce(r[:configs].last) do |cfg, (entry, prev)|
        back = Turing.undo(cfg, entry)
        assert_equal prev.to_h.slice(:state, :head), back.to_h.slice(:state, :head)
        back
      end
    end
    bad = Turing.run(initial: '1011', start: 'scan', rules: Turing::INCREMENT_RULES)
    forged = bad[:configs].dup
    forged[3], forged[4] = forged[4], forged[3]
    refute Turing.legal_trace?(forged, rules: Turing::INCREMENT_RULES)
  end

  # Invariant G (Agda: invariantG, position-injective)
  def test_spiral_bijection
    assert Spiral.verify_bijection(40_000)[:ok]
    s = 5
    pts = (0...(s * s * 3)).map { |i| Spiral.position3(i, s) }
    assert_equal pts.length, pts.uniq.length
    pts.each_with_index { |(x, y, z), i| assert_equal i, Spiral.index3(x, y, z, s) }
  end

  def test_fib_permutation
    (1..200).each do |n|
      p = Arrays.fib_perm(n)
      assert_equal (0...n).to_a, p.sort
      v = Array.new(n) { rng.rand(100) }
      assert_equal v, Arrays.fib_unpermute(Arrays.fib_permute(v))
    end
  end
end
