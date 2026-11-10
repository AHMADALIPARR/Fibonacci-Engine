# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Deterministic test-vector generator (fixed seed). Writes tests/equivalence/vectors.json.
#   ruby tests/equivalence/gen_vectors.rb
require 'json'

SEED = 20_261_110
rng = Random.new(SEED)
bits = ->(n) { Array.new(n) { rng.rand(2) }.join }

v = { 'seed' => SEED, 'generator' => 'tests/equivalence/gen_vectors.rb (Ruby Random, Mersenne Twister)' }
v['words'] = (1..25).to_a # 1 and 25 are outside the JS bound on purpose
v['braid'] = Array.new(40) { n = rng.rand(0..40); { 'x' => bits.call(n), 'y' => bits.call(n) } } +
             [{ 'x' => '101', 'y' => '10' }, { 'x' => '', 'y' => '1' }]
v['rep4_encode'] = Array.new(20) { bits.call(rng.rand(0..16)) }
v['rep4_decode'] = Array.new(10) { bits.call(rng.rand(0..8)).chars.map { |c| c * 4 }.join } +
                   ['0001', '111', '11110111', '0000111100001110']
v['tm'] = Array.new(25) { { 'initial' => bits.call(rng.rand(0..10)), 'maxSteps' => [10_000, 10_000, rng.rand(0..12)].sample(random: rng) } } +
          [{ 'initial' => '', 'maxSteps' => 10_000 }, { 'initial' => '12', 'maxSteps' => 10_000 }, { 'initial' => '1011', 'maxSteps' => 0 }]
v['workload'] = [{}, { 'targetTFLOPS' => 250, 'seconds' => 3600, 'flopsPerStep' => 7 }, { 'targetTFLOPS' => 0.5, 'seconds' => 0, 'flopsPerStep' => 1 },
                 { 'targetTFLOPS' => 1e3, 'seconds' => 2.5, 'flopsPerStep' => 3e5 }]
v['dna2'] = Array.new(20) { bits.call(2 * rng.rand(0..20)) } + ['1', '101']
v['pack'] = Array.new(20) { bits.call(rng.rand(0..40)) }
v['matrices'] = Array.new(10) { k = rng.rand(1..6); n = rng.rand(1..12); Array.new(k) { bits.call(n) } }
v['entropy'] = Array.new(12) { Array.new(rng.rand(1..60)) { %w[A C G T][rng.rand(4)] }.join } + ['AAAA', 'ATAATATAATAATATAATATA']
v['fibperm'] = (1..40).to_a
v['spiral_n'] = [1, 2, 9, 10, 25, 26, 500, 4096]
v['multistrand'] = Array.new(12) do
  k = rng.rand(2..5)
  n = rng.rand(1..10)
  ops = Array.new(rng.rand(1..6)) do
    case rng.rand(4)
    when 0 then "P:#{(0...k).to_a.shuffle(random: rng).join(',')}"
    when 1 then s, d = (0...k).to_a.sample(2, random: rng); "X:#{s}>#{d}"
    when 2 then "S:#{rng.rand(k - 1)}"
    else "s:#{rng.rand(k - 1)}"
    end
  end
  { 'state' => Array.new(k) { bits.call(n) }, 'program' => ops }
end
v['codes'] = Array.new(8) { k = rng.rand(1..4); n = rng.rand(4..9); Array.new(k) { bits.call(n) } }
File.write(File.join(__dir__, 'vectors.json'), JSON.pretty_generate(v) + "\n")
puts "wrote tests/equivalence/vectors.json (seed #{SEED})"
