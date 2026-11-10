-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Semantic translation of the ORIGINAL Alloy model braid_invariant.als into Agda.
--   abstract sig Bit; one sig Zero, One   ↦ data Bit
--   sig Pos                               ↦ Fin n (any finite number n of positions)
--   one sig Braid { x y a b : Pos -> one Bit } ↦ record BraidModel n (total functions Fin n → Bit)
--   fun bitxor[u,v] = (u = v) => Zero else One  ↦ bitxor (by cases)
--   fact BraidTransition                  ↦ fields transA, transB of the record
--   assert Reversible                     ↦ theorem reversible, for EVERY n (Alloy: exactly 8 Pos)
--   check Reversible for exactly 8 Pos    ↦ reversible {8} is a special case
--   run {} for exactly 8 Pos              ↦ model-exists: the facts are satisfiable for every n
module Braid.AlloyReversible where

open import Prelude

data Bit : Set where
  Zero One : Bit

bitxor : Bit → Bit → Bit
bitxor Zero Zero = Zero
bitxor One One = Zero
bitxor Zero One = One
bitxor One Zero = One

record BraidModel (n : Nat) : Set where
  field
    x y a b : Fin n → Bit
    transA : (p : Fin n) → a p ≡ y p
    transB : (p : Fin n) → b p ≡ bitxor (x p) (y p)

bitxor-recover : (u v : Bit) → u ≡ bitxor v (bitxor u v)
bitxor-recover Zero Zero = refl
bitxor-recover Zero One = refl
bitxor-recover One Zero = refl
bitxor-recover One One = refl

reversible : {n : Nat} (M : BraidModel n) (p : Fin n) →
             (BraidModel.x M p ≡ bitxor (BraidModel.a M p) (BraidModel.b M p)) × (BraidModel.y M p ≡ BraidModel.a M p)
reversible M p =
  trans (bitxor-recover (x p) (y p)) (sym (cong₂ bitxor (transA p) (transB p))) , sym (transA p)
  where open BraidModel M

-- The facts are not vacuous: for every n and every x, y there is a model.
model-exists : {n : Nat} (x y : Fin n → Bit) → BraidModel n
model-exists x y = record { x = x ; y = y ; a = y ; b = λ p → bitxor (x p) (y p)
                          ; transA = λ p → refl ; transB = λ p → refl }

-- The bounded Alloy command as an instance of the universal theorem.
check-exactly-8 : (M : BraidModel 8) (p : Fin 8) →
                  (BraidModel.x M p ≡ bitxor (BraidModel.a M p) (BraidModel.b M p)) × (BraidModel.y M p ≡ BraidModel.a M p)
check-exactly-8 = reversible
