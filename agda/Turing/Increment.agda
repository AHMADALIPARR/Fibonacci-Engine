-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- The binary-increment machine of the original JS (incrementRules), executed inside Agda's
-- type checker. The equalities below are checked by evaluation (refl) and must agree with the
-- JS oracle: input 1011 → HALT after 8 steps, tape 1100, head at cell 1.
module Turing.Increment where

open import Prelude
open import Turing.Machine
open import Turing.Trace

data Q : Set where
  scan carry halt : Q

data Σ₃ : Set where
  s0 s1 blank : Σ₃

isHaltQ : Q → Bool
isHaltQ halt = true
isHaltQ _ = false

δinc : Q → Σ₃ → Maybe (Σ₃ × (Move × Q))
δinc scan s0 = just (s0 , (R , scan))
δinc scan s1 = just (s1 , (R , scan))
δinc scan blank = just (blank , (L , carry))
δinc carry s1 = just (s0 , (L , carry))
δinc carry s0 = just (s1 , (S , halt))
δinc carry blank = just (s1 , (S , halt))
δinc halt _ = nothing

eqQ : Q → Q → Bool
eqQ scan scan = true
eqQ carry carry = true
eqQ halt halt = true
eqQ _ _ = false

eqQ-sound : (p q : Q) → eqQ p q ≡ true → p ≡ q
eqQ-sound scan scan _ = refl
eqQ-sound carry carry _ = refl
eqQ-sound halt halt _ = refl
eqQ-sound scan carry ()
eqQ-sound scan halt ()
eqQ-sound carry scan ()
eqQ-sound carry halt ()
eqQ-sound halt scan ()
eqQ-sound halt carry ()

eqΣ : Σ₃ → Σ₃ → Bool
eqΣ s0 s0 = true
eqΣ s1 s1 = true
eqΣ blank blank = true
eqΣ _ _ = false

eqΣ-sound : (a b : Σ₃) → eqΣ a b ≡ true → a ≡ b
eqΣ-sound s0 s0 _ = refl
eqΣ-sound s1 s1 _ = refl
eqΣ-sound blank blank _ = refl
eqΣ-sound s0 s1 ()
eqΣ-sound s0 blank ()
eqΣ-sound s1 s0 ()
eqΣ-sound s1 blank ()
eqΣ-sound blank s0 ()
eqΣ-sound blank s1 ()

Inc : Machine
Inc = record { State = Q ; Sym = Σ₃ ; blank = blank ; isHalt = isHaltQ ; δ = δinc
             ; eqState = eqQ ; eqState-sound = eqQ-sound ; eqSym = eqΣ ; eqSym-sound = eqΣ-sound }

open Semantics Inc
open Traces Inc

-- Initial configuration: tape 1011, head on cell 0, state scan (JS: initial '1011', start 'scan').
init : Config
init = conf scan [] s1 (s0 ∷ s1 ∷ s1 ∷ []) (+ 0)

trace : List Config
trace = runTrace 20 init

final : Config
final = last init trace

-- Tape contents from leftmost to rightmost stored cell, blanks trimmed (JS getTape convention).
rev : List Σ₃ → List Σ₃ → List Σ₃
rev [] acc = acc
rev (x ∷ xs) acc = rev xs (x ∷ acc)

trimL : List Σ₃ → List Σ₃
trimL (blank ∷ xs) = trimL xs
trimL xs = xs

tapeOf : Config → List Σ₃
tapeOf c = rev (trimL (rev (trimL (rev (left c) (cur c ∷ right c))) [])) []

steps-8 : length trace ≡ 9
steps-8 = refl

final-halt : state final ≡ halt
final-halt = refl

final-tape : tapeOf final ≡ s1 ∷ s1 ∷ s0 ∷ s0 ∷ []
final-tape = refl

final-head : pos final ≡ + 1
final-head = refl

accepted : accepts init trace ≡ true
accepted = refl

-- Invariant F applied: the accepted trace is a legal chain from init ending in HALT.
legal : Chain init trace × (isHaltQ (state (last init trace)) ≡ true)
legal = invariantF init trace accepted

-- Invariant E applied to this machine: its next-step relation is deterministic.
inc-deterministic : {c c1 c2 : Config} → Step c c1 → Step c c2 → c1 ≡ c2
inc-deterministic = step-deterministic
