-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant B: braid inversion, B(x,y) = (y, x xor y), B⁻¹(a,b) = (a xor b, a).
module Braid.XorBraid where

open import Prelude

xor-cancel : (x y : Bool) → xor y (xor x y) ≡ x
xor-cancel false false = refl
xor-cancel false true = refl
xor-cancel true false = refl
xor-cancel true true = refl

xor-back : (a b : Bool) → xor (xor a b) a ≡ b
xor-back false false = refl
xor-back false true = refl
xor-back true false = refl
xor-back true true = refl

xor-comm : (a b : Bool) → xor a b ≡ xor b a
xor-comm false false = refl
xor-comm false true = refl
xor-comm true false = refl
xor-comm true true = refl

xorV : {n : Nat} → Vec Bool n → Vec Bool n → Vec Bool n
xorV [] [] = []
xorV (x ∷ xs) (y ∷ ys) = xor x y ∷ xorV xs ys

-- Equal lengths are enforced by the type index n (unequal lanes are not expressible).
braid : {n : Nat} → Vec Bool n × Vec Bool n → Vec Bool n × Vec Bool n
braid (x , y) = y , xorV x y

unbraid : {n : Nat} → Vec Bool n × Vec Bool n → Vec Bool n × Vec Bool n
unbraid (a , b) = xorV a b , a

xorV-cancel : {n : Nat} (x y : Vec Bool n) → xorV y (xorV x y) ≡ x
xorV-cancel [] [] = refl
xorV-cancel (x ∷ xs) (y ∷ ys) = cong₂ _∷_ (xor-cancel x y) (xorV-cancel xs ys)

xorV-back : {n : Nat} (a b : Vec Bool n) → xorV (xorV a b) a ≡ b
xorV-back [] [] = refl
xorV-back (a ∷ as) (b ∷ bs) = cong₂ _∷_ (xor-back a b) (xorV-back as bs)

-- Invariant B (every input bit restored, all lengths n).
invariantB : {n : Nat} (x y : Vec Bool n) → unbraid (braid (x , y)) ≡ (x , y)
invariantB x y = cong (λ v → v , y) (xorV-cancel x y)

-- The other composition.
braid-unbraid : {n : Nat} (a b : Vec Bool n) → braid (unbraid (a , b)) ≡ (a , b)
braid-unbraid a b = cong (λ v → a , v) (xorV-back a b)

-- Universal counterpart of the bounded Alloy temporal check OrderThree: B∘B∘B = id.
xor-order3 : (x y : Bool) → xor (xor x y) (xor y (xor x y)) ≡ y
xor-order3 false false = refl
xor-order3 false true = refl
xor-order3 true false = refl
xor-order3 true true = refl

xorV-order3 : {n : Nat} (x y : Vec Bool n) → xorV (xorV x y) (xorV y (xorV x y)) ≡ y
xorV-order3 [] [] = refl
xorV-order3 (x ∷ xs) (y ∷ ys) = cong₂ _∷_ (xor-order3 x y) (xorV-order3 xs ys)

braid-order3 : {n : Nat} (x y : Vec Bool n) → braid (braid (braid (x , y))) ≡ (x , y)
braid-order3 x y = cong₂ _,_ (xorV-cancel x y) (xorV-order3 x y)

-- B is not an involution (counterexample, matching Alloy's InvolutionClaim counterexample).
not-involution : ¬ ((x y : Vec Bool 1) → braid (braid (x , y)) ≡ (x , y))
not-involution h with h (true ∷ []) (false ∷ [])
... | ()
