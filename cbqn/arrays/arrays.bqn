# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# Packed binary arrays, Hamming metrics, binary linear codes, Fibonacci-indexed permutation,
# frequency/entropy statistics.

# Pack bits MSB-first into bytes; final byte zero-padded. Result: ⟨length, bytes⟩.
Pack ⇐ {
  "non-binary symbol" ! ∧´𝕩∊0‿1
  ⟨≠𝕩, (2⋆⌽↕8) +´∘×⎉1 ∘‿8⥊ 𝕩 ∾ (8|-≠𝕩)⥊0⟩
}
Unpack ⇐ {𝕊 l‿b:
  "byte count does not match length" ! (≠b) = ⌊(l+7)÷8
  bits ← ⥊ 2|⌊ b ÷⌜ 2⋆⌽↕8
  "nonzero padding bits" ! ∧´ 0 = l↓bits
  l↑bits
}

Weight ⇐ +´
Distance ⇐ {+´𝕨≠𝕩}
# Hamming distance matrix of the rows of 𝕩 (k×n boolean matrix).
DistMatrix ⇐ {(+´≠)⌜˜ <˘𝕩}
Weights ⇐ +´˘

# Fourfold repetition code (trivial construction from the original JS): 0 → 0000, 1 → 1111.
Rep4 ⇐ {"non-binary symbol" ! ∧´𝕩∊0‿1 ⋄ 4/𝕩}
Rep4Decode ⇐ {
  "code length is not a multiple of 4" ! 0=4|≠𝕩
  m ← ∘‿4⥊𝕩
  "block is not a codeword" ! ∧´ (∧´˘m) ∨ ¬∨´˘m
  ⊏˘m
}
# Nearest-codeword decoding: weight ≥ 3 → 1, ≤ 1 → 0, weight 2 is a detected uncorrectable error.
Rep4Correct ⇐ {
  "code length is not a multiple of 4" ! 0=4|≠𝕩
  w ← +´˘ ∘‿4⥊𝕩
  "equidistant block: error detected, not correctable" ! ∧´ w≠2
  w ≥ 3
}

# Span of a k×n generator matrix over GF(2); row m of the result is the codeword of message m
# (message bits MSB-first).
Span ⇐ {𝕊 g:
  k ← ≠g
  msgs ← 2| ⌊ (↕2⋆k) ÷⌜ 2⋆⌽↕k
  2| msgs +˝∘×⎉1‿∞ g
}
Member ⇐ {c 𝕊 x: (<x) ∊ <˘c}
# XOR-closure: ⟨1⟩ if closed, else ⟨0, i, j⟩ for the first pair (row-major) whose XOR is not a codeword.
Closure ⇐ {𝕊 c:
  rows ← <˘c
  ok ← ⥊ rows {⊑(<𝕨≠𝕩)∊rows}⌜ rows
  idx ← ⥊↕2⥊≠rows
  {𝕩 ? ⟨1⟩ ; ⟨0⟩ ∾ (⊑ok⊐0)⊑idx} ∧´ok
}
# Doubly even: ⟨1⟩ or ⟨0, i, weight⟩ for the first row whose weight is not ≡ 0 (mod 4).
DoublyEven ⇐ {𝕊 c:
  w ← +´˘c
  {𝕩 ? ⟨1⟩ ; i ← ⊑ (0≠4|w) / ↕≠w ⋄ ⟨0, i, i⊑w⟩} ∧´ 0=4|w
}
MinDistance ⇐ {𝕊 c: d ← DistMatrix c ⋄ ⌊´ (⥊ (<⌜˜↕≠c)) / ⥊d}

# Extended Hamming [8,4,4] generator (classical code, explicitly constructed).
extHamming ⇐ >⟨1‿0‿0‿0‿0‿1‿1‿1, 0‿1‿0‿0‿1‿0‿1‿1, 0‿0‿1‿0‿1‿1‿0‿1, 0‿0‿0‿1‿1‿1‿1‿0⟩

# Distinct length-𝕨 windows of a word, sorted (candidate set for counterexample search).
Windows ⇐ {w 𝕊 word: ∧ ⍷ <˘ w ↕ word}

# Fibonacci-indexed permutation of ↕n: stride F = largest Fibonacci number ≤ n coprime to n,
# p[i] = (i×F) mod n.
Gcd ⇐ {𝕨 {𝕩=0 ? 𝕨 ; 𝕩 𝕊 𝕩|𝕨} 𝕩}
FibStride ⇐ {𝕊 n:
  fs ← {𝕩∾+´¯2↑𝕩} •_while_ {n ≥ +´¯2↑𝕩} 1‿1
  ⌈´ (1 = n Gcd¨ fs) / fs
}
FibPerm ⇐ {𝕊 n: n | (FibStride n) × ↕n}
FibPermute ⇐ {(FibPerm ≠𝕩) ⊏ 𝕩}
FibUnpermute ⇐ {(⍋FibPerm ≠𝕩) ⊏ 𝕩}

# Frequencies of the distinct symbols of 𝕩 in ascending order and Shannon entropy in bits:
# H = (Σ −p·ln p, summed left to right) ÷ ln 2.
Frequencies ⇐ {s ← ∧⍷𝕩 ⋄ ⟨s, +´˘ s =⌜ 𝕩⟩}
Entropy ⇐ {
  s‿c ← Frequencies 𝕩
  p ← c ÷ ≠𝕩
  (0 {𝕩+𝕨}´ ⌽ -p × ⋆⁼p) ÷ ⋆⁼2
}
