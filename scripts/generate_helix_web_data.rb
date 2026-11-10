#!/usr/bin/env ruby
# SPDX-License-Identifier: AGPL-3.0-only
# Generate raw topological arrays for the Morphic Helix web frontend (docs/helix-data.json).
# Usage: ruby scripts/generate_helix_web_data.rb [depth] > docs/helix-data.json
require 'json'
require_relative '../ruby/application/fibonacci'
require_relative '../ruby/application/dna'
require_relative '../ruby/application/braid'

include MorphicHelix

depth = (ARGV[0] || 6).to_i
word = Fibonacci.word(depth)
dna = DNA.compat_encode(word)
y = Braid.rotate(word, 5)
a, b = Braid.braid(word, y)
rx, ry = Braid.unbraid(a, b)

points = dna.chars.each_with_index.map do |base, i|
  phase = i * (2 * Math::PI / 10.5)
  {
    index: i,
    base: base,
    complement: DNA.complement(base),
    phase: phase,
    radius: 1.0,
    height: i * 0.4
  }
end

data = {
  schema: 'morphic-helix/web-frontend/1',
  generated_at: Time.now.utc.iso8601,
  depth: depth,
  word_length: word.length,
  dna: dna,
  bits: word,
  braid: {
    x: word, y: y, a: a, b: b,
    restored_x: rx, restored_y: ry,
    reversible: rx == word && ry == y
  },
  helix_points: points,
  notes: [
    'Raw topological arrays from the Ruby Morphic Helix engine.',
    'Consumed by the web frontend under docs/ (GitHub Pages).',
    'Drive via headless Chromium for screenshots matching the desktop Morphic GUI.'
  ]
}

puts JSON.pretty_generate(data)
