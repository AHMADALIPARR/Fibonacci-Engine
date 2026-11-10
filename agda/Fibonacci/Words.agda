-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant A: Fibonacci word lengths. W0 = A, W1 = AB, W(n+2) = W(n+1) ++ W(n).
module Fibonacci.Words where

open import Prelude

data Sym : Set where
  A B : Sym

word : Nat → List Sym
word zero = A ∷ []
word (suc zero) = A ∷ B ∷ []
word (suc (suc n)) = word (suc n) ++ word n

-- Invariant A, for every n (induction is carried by length-++, proved by induction on the list).
invariantA : (n : Nat) → length (word (suc (suc n))) ≡ length (word (suc n)) + length (word n)
invariantA n = length-++ (word (suc n)) (word n)

-- Closed form of the length: |W n| = F (n + 2) with F 0 = 0, F 1 = 1.
fib : Nat → Nat
fib zero = zero
fib (suc zero) = suc zero
fib (suc (suc n)) = fib (suc n) + fib n

-- Proved by two-step induction over the recursive construction.
length-fib : (n : Nat) → length (word n) ≡ fib (suc (suc n))
length-fib zero = refl
length-fib (suc zero) = refl
length-fib (suc (suc n)) =
  trans (invariantA n)
        (cong₂ _+_ (length-fib (suc n)) (length-fib n))

-- Prefix property checked by the JS original: W(n+1) begins with W(n).
prefix : (n : Nat) → Σ (List Sym) (λ rest → word (suc n) ≡ word n ++ rest)
prefix zero = B ∷ [] , refl
prefix (suc n) = word n , refl

-- Concrete check against the JS oracle: W6 (the 21-symbol word of main()) as A/B text.
private
  w6 : List Sym
  w6 = A ∷ B ∷ A ∷ A ∷ B ∷ A ∷ B ∷ A ∷ A ∷ B ∷ A ∷ A ∷ B ∷ A ∷ B ∷ A ∷ A ∷ B ∷ A ∷ B ∷ A ∷ []

word6-oracle : word 6 ≡ w6
word6-oracle = refl

length6 : length (word 6) ≡ 21
length6 = refl
