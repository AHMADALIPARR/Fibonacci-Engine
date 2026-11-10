-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant D: coding structure of the explicitly constructed fourfold repetition code
-- (0 ↦ 0000, 1 ↦ 1111). This is the trivial construction from the original JS; nothing here is
-- asserted for arbitrary Fibonacci-generated windows (see the counterexample at the end).
module Coding.Repetition where

open import Prelude
open import Braid.XorBraid using (xorV)

quad : Nat → Nat
quad zero = zero
quad (suc n) = suc (suc (suc (suc (quad n))))

rep4 : {n : Nat} → Vec Bool n → Vec Bool (quad n)
rep4 [] = []
rep4 (b ∷ bs) = b ∷ b ∷ b ∷ b ∷ rep4 bs

weight : {n : Nat} → Vec Bool n → Nat
weight [] = zero
weight (true ∷ xs) = suc (weight xs)
weight (false ∷ xs) = weight xs

-- The code C_n = image of rep4 on messages of length n.
InCode : {n : Nat} → Vec Bool (quad n) → Set
InCode {n} w = Σ (Vec Bool n) (λ u → rep4 u ≡ w)

rep4-linear : {n : Nat} (u v : Vec Bool n) → xorV (rep4 u) (rep4 v) ≡ rep4 (xorV u v)
rep4-linear [] [] = refl
rep4-linear (a ∷ u) (b ∷ v) = cong (λ t → xor a b ∷ xor a b ∷ xor a b ∷ xor a b ∷ t) (rep4-linear u v)

-- Closure under XOR, for every block count n.
xor-closed : {n : Nat} (w1 w2 : Vec Bool (quad n)) → InCode w1 → InCode w2 → InCode (xorV w1 w2)
xor-closed .(rep4 u) .(rep4 v) (u , refl) (v , refl) = xorV u v , sym (rep4-linear u v)

weight-rep4 : {n : Nat} (u : Vec Bool n) → weight (rep4 u) ≡ quad (weight u)
weight-rep4 [] = refl
weight-rep4 (true ∷ u) = cong (λ k → suc (suc (suc (suc k)))) (weight-rep4 u)
weight-rep4 (false ∷ u) = weight-rep4 u

Div4 : Nat → Set
Div4 m = Σ Nat (λ k → m ≡ quad k)

-- Doubly even: every codeword weight is ≡ 0 (mod 4).
doubly-even : {n : Nat} (w : Vec Bool (quad n)) → InCode w → Div4 (weight w)
doubly-even .(rep4 u) (u , refl) = weight u , weight-rep4 u

-- Distance between codewords is 4 × distance between messages; minimum distance is 4.
dist : {n : Nat} → Vec Bool n → Vec Bool n → Nat
dist u v = weight (xorV u v)

dist-rep4 : {n : Nat} (u v : Vec Bool n) → dist (rep4 u) (rep4 v) ≡ quad (dist u v)
dist-rep4 u v = trans (cong weight (rep4-linear u v)) (weight-rep4 (xorV u v))

xor-self : (b : Bool) → xor b b ≡ false
xor-self false = refl
xor-self true = refl

weight-zero→eq : {n : Nat} (u v : Vec Bool n) → dist u v ≡ zero → u ≡ v
weight-zero→eq [] [] _ = refl
weight-zero→eq (false ∷ u) (false ∷ v) p = cong (false ∷_) (weight-zero→eq u v p)
weight-zero→eq (true ∷ u) (true ∷ v) p = cong (true ∷_) (weight-zero→eq u v p)
weight-zero→eq (false ∷ u) (true ∷ v) ()
weight-zero→eq (true ∷ u) (false ∷ v) ()

min-distance-4 : {n : Nat} (u v : Vec Bool n) → u ≢ v → 4 ≤ dist (rep4 u) (rep4 v)
min-distance-4 u v neq with dist u v in eq
... | zero = ⊥-elim (neq (weight-zero→eq u v eq))
... | suc k rewrite dist-rep4 u v | eq = s≤s (s≤s (s≤s (s≤s z≤n)))

-- Decoding one block of 4 bits by nearest codeword: weight ≥ 3 ↦ 1, ≤ 1 ↦ 0, 2 ↦ detected error.
decodeBlock : Bool → Bool → Bool → Bool → Maybe Bool
decodeBlock a b c d = classify (weight (a ∷ b ∷ c ∷ d ∷ []))
  where
    classify : Nat → Maybe Bool
    classify zero = just false
    classify (suc zero) = just false
    classify (suc (suc zero)) = nothing
    classify (suc (suc (suc _))) = just true

block : Bool → Vec Bool 4
block b = b ∷ b ∷ b ∷ b ∷ []

flip : {n : Nat} → Fin n → Vec Bool n → Vec Bool n
flip zero (x ∷ xs) = not x ∷ xs
flip (suc i) (x ∷ xs) = x ∷ flip i xs

decodeV : Vec Bool 4 → Maybe Bool
decodeV (a ∷ b ∷ c ∷ d ∷ []) = decodeBlock a b c d

decode-clean : (b : Bool) → decodeV (block b) ≡ just b
decode-clean false = refl
decode-clean true = refl

-- Minimum distance 4 ⇒ every single-bit error in a block is corrected.
corrects-single-error : (b : Bool) (j : Fin 4) → decodeV (flip j (block b)) ≡ just b
corrects-single-error false zero = refl
corrects-single-error false (suc zero) = refl
corrects-single-error false (suc (suc zero)) = refl
corrects-single-error false (suc (suc (suc zero))) = refl
corrects-single-error true zero = refl
corrects-single-error true (suc zero) = refl
corrects-single-error true (suc (suc zero)) = refl
corrects-single-error true (suc (suc (suc zero))) = refl

-- Every double-bit error is detected (decoder returns nothing) rather than miscorrected.
detects-double-error : (b : Bool) (i j : Fin 4) → (toNat i < toNat j) ≡ true → decodeV (flip i (flip j (block b))) ≡ nothing
detects-double-error false zero (suc zero) _ = refl
detects-double-error false zero (suc (suc zero)) _ = refl
detects-double-error false zero (suc (suc (suc zero))) _ = refl
detects-double-error false (suc zero) (suc (suc zero)) _ = refl
detects-double-error false (suc zero) (suc (suc (suc zero))) _ = refl
detects-double-error false (suc (suc zero)) (suc (suc (suc zero))) _ = refl
detects-double-error true zero (suc zero) _ = refl
detects-double-error true zero (suc (suc zero)) _ = refl
detects-double-error true zero (suc (suc (suc zero))) _ = refl
detects-double-error true (suc zero) (suc (suc zero)) _ = refl
detects-double-error true (suc zero) (suc (suc (suc zero))) _ = refl
detects-double-error true (suc (suc zero)) (suc (suc (suc zero))) _ = refl
detects-double-error b zero zero ()
detects-double-error b (suc zero) zero ()
detects-double-error b (suc zero) (suc zero) ()
detects-double-error b (suc (suc zero)) zero ()
detects-double-error b (suc (suc zero)) (suc zero) ()
detects-double-error b (suc (suc zero)) (suc (suc zero)) ()
detects-double-error b (suc (suc (suc zero))) zero ()
detects-double-error b (suc (suc (suc zero))) (suc zero) ()
detects-double-error b (suc (suc (suc zero))) (suc (suc zero)) ()
detects-double-error b (suc (suc (suc zero))) (suc (suc (suc zero))) ()

-- Counterexample: the set of distinct length-2 windows of the Fibonacci word W3 = 01001
-- is {00, 01, 10}; it is not XOR-closed (01 xor 10 = 11 is not a window).
data Win : Vec Bool 2 → Set where
  w00 : Win (false ∷ false ∷ [])
  w01 : Win (false ∷ true ∷ [])
  w10 : Win (true ∷ false ∷ [])

windows-not-closed : ¬ ((u v : Vec Bool 2) → Win u → Win v → Win (xorV u v))
windows-not-closed h with h (false ∷ true ∷ []) (true ∷ false ∷ []) w01 w10
... | ()
