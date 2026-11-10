-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Minimal self-contained prelude (only Agda.Builtin modules; no standard library, no postulates).
module Prelude where

open import Agda.Builtin.Nat public
  using (Nat; zero; suc; _+_; _*_; _-_; _<_; _==_)
open import Agda.Builtin.Bool public using (Bool; true; false)
open import Agda.Builtin.Equality public using (_≡_; refl)
open import Agda.Builtin.List public using (List; []; _∷_)
open import Agda.Builtin.Sigma public using (Σ; _,_; fst; snd)
open import Agda.Builtin.Maybe public using (Maybe; just; nothing)
open import Agda.Builtin.Unit public using (⊤; tt)

infixr 5 _++_
infixr 2 _×_
infix 4 _≢_

data ⊥ : Set where

⊥-elim : {A : Set} → ⊥ → A
⊥-elim ()

¬_ : Set → Set
¬ A = A → ⊥

_≢_ : {A : Set} → A → A → Set
x ≢ y = ¬ (x ≡ y)

_×_ : Set → Set → Set
A × B = Σ A (λ _ → B)

sym : {A : Set} {x y : A} → x ≡ y → y ≡ x
sym refl = refl

trans : {A : Set} {x y z : A} → x ≡ y → y ≡ z → x ≡ z
trans refl q = q

cong : {A B : Set} (f : A → B) {x y : A} → x ≡ y → f x ≡ f y
cong f refl = refl

cong₂ : {A B C : Set} (f : A → B → C) {x y : A} {u v : B} → x ≡ y → u ≡ v → f x u ≡ f y v
cong₂ f refl refl = refl

subst : {A : Set} (P : A → Set) {x y : A} → x ≡ y → P x → P y
subst P refl p = p

just-inj : {A : Set} {x y : A} → just x ≡ just y → x ≡ y
just-inj refl = refl

suc-inj : {m n : Nat} → suc m ≡ suc n → m ≡ n
suc-inj refl = refl

true≢false : true ≢ false
true≢false ()

not : Bool → Bool
not true = false
not false = true

_∧_ : Bool → Bool → Bool
true ∧ b = b
false ∧ _ = false

if_then_else_ : {A : Set} → Bool → A → A → A
if true then x else _ = x
if false then _ else y = y

-- Lists
_++_ : {A : Set} → List A → List A → List A
[] ++ ys = ys
(x ∷ xs) ++ ys = x ∷ (xs ++ ys)

length : {A : Set} → List A → Nat
length [] = zero
length (_ ∷ xs) = suc (length xs)

length-++ : {A : Set} (xs ys : List A) → length (xs ++ ys) ≡ length xs + length ys
length-++ [] ys = refl
length-++ (x ∷ xs) ys = cong suc (length-++ xs ys)

-- Vectors and finite sets (dependent types for valid indices)
data Vec (A : Set) : Nat → Set where
  []  : Vec A zero
  _∷_ : {n : Nat} → A → Vec A n → Vec A (suc n)

data Fin : Nat → Set where
  zero : {n : Nat} → Fin (suc n)
  suc  : {n : Nat} → Fin n → Fin (suc n)

toNat : {n : Nat} → Fin n → Nat
toNat zero = zero
toNat (suc i) = suc (toNat i)

lookup : {A : Set} {n : Nat} → Vec A n → Fin n → A
lookup (x ∷ _) zero = x
lookup (_ ∷ xs) (suc i) = lookup xs i

-- Order on Nat (inductive)
data _≤_ : Nat → Nat → Set where
  z≤n : {n : Nat} → zero ≤ n
  s≤s : {m n : Nat} → m ≤ n → suc m ≤ suc n

≤-refl : (n : Nat) → n ≤ n
≤-refl zero = z≤n
≤-refl (suc n) = s≤s (≤-refl n)

≤-step : {m n : Nat} → m ≤ n → m ≤ suc n
≤-step z≤n = z≤n
≤-step (s≤s p) = s≤s (≤-step p)

toNat-< : {n : Nat} (i : Fin n) → suc (toNat i) ≤ n
toNat-< zero = s≤s z≤n
toNat-< (suc i) = s≤s (toNat-< i)

-- Arithmetic lemmas
+-zero : (n : Nat) → n + zero ≡ n
+-zero zero = refl
+-zero (suc n) = cong suc (+-zero n)

+-suc : (m n : Nat) → m + suc n ≡ suc (m + n)
+-suc zero n = refl
+-suc (suc m) n = cong suc (+-suc m n)

+-comm : (m n : Nat) → m + n ≡ n + m
+-comm zero n = sym (+-zero n)
+-comm (suc m) n = trans (cong suc (+-comm m n)) (sym (+-suc n m))

+-assoc : (a b c : Nat) → (a + b) + c ≡ a + (b + c)
+-assoc zero b c = refl
+-assoc (suc a) b c = cong suc (+-assoc a b c)

==-refl : (n : Nat) → (n == n) ≡ true
==-refl zero = refl
==-refl (suc n) = ==-refl n

==-sound : (m n : Nat) → (m == n) ≡ true → m ≡ n
==-sound zero zero _ = refl
==-sound zero (suc n) ()
==-sound (suc m) zero ()
==-sound (suc m) (suc n) p = cong suc (==-sound m n p)

<-irrefl : (n : Nat) → (n < n) ≡ false
<-irrefl zero = refl
<-irrefl (suc n) = <-irrefl n

≤→¬> : {m n : Nat} → m ≤ n → (n < m) ≡ false
≤→¬> {n = zero} z≤n = refl
≤→¬> {n = suc n} z≤n = refl
≤→¬> (s≤s p) = ≤→¬> p

<→≤ : (m n : Nat) → (m < n) ≡ true → suc m ≤ n
<→≤ zero zero ()
<→≤ zero (suc n) _ = s≤s z≤n
<→≤ (suc m) zero ()
<→≤ (suc m) (suc n) p = s≤s (<→≤ m n p)

≤-antisym : {m n : Nat} → m ≤ n → n ≤ m → m ≡ n
≤-antisym z≤n z≤n = refl
≤-antisym (s≤s p) (s≤s q) = cong suc (≤-antisym p q)

¬<→≤ : (m n : Nat) → (m < n) ≡ false → n ≤ m
¬<→≤ m zero _ = z≤n
¬<→≤ zero (suc n) ()
¬<→≤ (suc m) (suc n) p = s≤s (¬<→≤ m n p)

-- Boolean bit operations
xor : Bool → Bool → Bool
xor false b = b
xor true b = not b

data Int : Set where
  +_     : Nat → Int
  -[1+_] : Nat → Int
