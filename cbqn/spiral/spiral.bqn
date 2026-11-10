# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# Square (Ulam) spiral indexing on Z²: index 0 ↦ (0,0); ring r ≥ 1 holds indices (2r-1)² … (2r+1)²-1,
# four sides of 2r cells:  s=0: ( r, 1-r+t)  s=1: (r-1-t,  r)  s=2: (-r, r-1-t)  s=3: (1-r+t, -r)
# Pure index arithmetic for data layout, not a physical simulation.

ISqrt ⇐ {m ← ⌊√𝕩 ⋄ m +↩ 𝕩 ≥ ×˜m+1 ⋄ m - 𝕩 < ×˜m}
# Ring coordinates r‿s‿t for each index of the list 𝕩 (rows of the result).
RingCoord ⇐ {
  r ← ⌊ (1 + ISqrt 𝕩) ÷ 2
  off ← 𝕩 - ×˜ 1 -˜ 2×r
  w ← 1 ⌈ 2×r
  (r≠0) × ⍉>⟨r, ⌊off÷w, w|off⟩
}
Position ⇐ {
  r‿s‿t ← <˘⍉ RingCoord 𝕩
  x ← s ⊑¨ <˘⍉ >⟨r, (r-1)-t, -r, (1-r)+t⟩
  y ← s ⊑¨ <˘⍉ >⟨(1-r)+t, r, (r-1)-t, -r⟩
  (r≠0) × x ≍˘ y
}
Index ⇐ {𝕊 x‿y:
  r ← (|x) ⌈ |y
  s ← {(x=r)∧y>-r ? 0 ; y=r ? 1 ; x=-r ? 2 ; 3}
  t ← s ⊑ ⟨y+r-1, (r-1)-x, (r-1)-y, x+r-1⟩
  (r≠0) × (×˜ 1-˜2×r) + (s×2×r) + t
}
# Bijection check for the first n indices: positions pairwise distinct and Index∘Position = identity.
VerifyBijection ⇐ {𝕊 n:
  p ← Position ↕n
  (∧´ ∊<˘p) ∧ (↕n) ≡ Index¨ <˘p
}
# 3-D layout of a side×side×depth array (side odd): i ↦ x‿y‿z, z = ⌊i÷side², (x,y) = Position side²|i.
Position3 ⇐ {side 𝕊 i:
  "side must be odd" ! 1=2|side
  (Position (×˜side)|i) ∾˘ ⌊i÷×˜side
}
