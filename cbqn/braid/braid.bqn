# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# XOR braid on equal-length bit lanes (booleans; ≠ is XOR on 0/1).
#   Braid:   x‿y → ⟨y, x XOR y⟩       Unbraid: a‿b → ⟨a XOR b, a⟩
# Unequal lengths are rejected (explicit policy; no truncation).
Braid ⇐ {x 𝕊 y: "braid length mismatch" ! x ≡○≠ y ⋄ "non-binary symbol" ! ∧´(x∾y)∊0‿1 ⋄ ⟨y, x≠y⟩}
Unbraid ⇐ {a 𝕊 b: "unbraid length mismatch" ! a ≡○≠ b ⋄ ⟨a≠b, a⟩}

# Batched: 𝕨 and 𝕩 are equal-shape arrays whose last axis is the lane; every leading cell is one pair.
BatchBraid ⇐ {x 𝕊 y: "batch shape mismatch" ! x ≡○≢ y ⋄ ⟨y, x≠y⟩}
BatchUnbraid ⇐ {a 𝕊 b: "batch shape mismatch" ! a ≡○≢ b ⋄ ⟨a≠b, a⟩}

# Multistrand state: k×n boolean matrix, one strand per row in deterministic row order.
# An operator is ⟨kind, args⟩ with kind 'P' (permute, args p), 'X' (xormix, args src‿dst),
# 'S' (sigma on rows i,i+1), 's' (inverse sigma).
Apply ⇐ {op 𝕊 st:
  k‿a ← op ⋄ n ← ≠st
  {
    k='P' ? "not a permutation" ! (∧a)≡↕n ⋄ a⊏st ;
    k='X' ? s‿d ← a ⋄ "bad xormix" ! (s≠d) ∧ (s<n) ∧ d<n ⋄ ((d⊏st)≠s⊏st)⌾(d⊸⊏) st ;
    k='S' ? i ← ⊑a ⋄ "bad sigma" ! n>i+1 ⋄ x‿y ← <˘ i‿(i+1)⊏st ⋄ (>⟨y, x≠y⟩)⌾(i‿(i+1)⊸⊏) st ;
    k='s' ? i ← ⊑a ⋄ "bad sigma" ! n>i+1 ⋄ p‿q ← <˘ i‿(i+1)⊏st ⋄ (>⟨p≠q, p⟩)⌾(i‿(i+1)⊸⊏) st ;
    "unknown operator" ! 0
  }
}
Inverse ⇐ {𝕊 k‿a: {k='P' ? ⟨'P', ⍋a⟩ ; k='X' ? ⟨'X', a⟩ ; k='S' ? ⟨'s', a⟩ ; ⟨'S', a⟩}}
InverseProgram ⇐ {Inverse¨ ⌽𝕩}
Run ⇐ {prog 𝕊 st: st {𝕨 Apply 𝕩}´ ⌽prog}
# All intermediate states (history), first element is the input state.
History ⇐ {prog 𝕊 st: {𝕩 ∾ <(⊑⟜prog ¯1+≠𝕩) Apply ¯1⊑𝕩}⍟(≠prog) ⟨st⟩}
# Smallest p ≥ 1 with Run^p st ≡ st, searched up to limit 𝕨 (returns ¯1 when not found).
Period ⇐ {lim‿prog 𝕊 st:
  r ← {c‿i: ⟨prog Run c, i+1⟩} •_while_ {c‿i: (i<lim) ∧ (i=0) ∨ ¬c≡st} ⟨st, 0⟩
  (st ≡ ⊑r) ⊑ ¯1‿(1⊑r)
}
Serialize ⇐ {"MH1|k=" ∾ (•Repr ≠𝕩) ∾ "|n=" ∾ (•Repr 1⊑≢𝕩) ∾ ⥊ {'|' ∾ '0'+𝕩}˘ 𝕩}
