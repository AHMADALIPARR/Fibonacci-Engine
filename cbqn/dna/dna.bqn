# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# DNA encodings.
#   compatibility mode (original JS DNA=['A','T']): 0 → 'A', 1 → 'T'
#   two-bit mode: 00 → A, 01 → C, 10 → G, 11 → T (first bit is the high bit)
Compat ⇐ {"non-binary symbol" ! ∧´𝕩∊0‿1 ⋄ 𝕩⊏"AT"}
CompatDecode ⇐ {i←"AT"⊐𝕩 ⋄ "base not in A/T" ! ∧´i<2 ⋄ i}
Encode2 ⇐ {
  "non-binary symbol" ! ∧´𝕩∊0‿1
  "odd-length input rejected" ! 0=2|≠𝕩
  m ← ∘‿2⥊𝕩
  ((2×⊏˘m)+1⊏˘m)⊏"ACGT"
}
Decode2 ⇐ {
  i ← "ACGT"⊐𝕩
  "base not in ACGT" ! ∧´i<4
  ⥊ (⌊i÷2) ≍˘ 2|i
}
Complement ⇐ {("ACGT"⊐𝕩)⊏"TGCA"}
