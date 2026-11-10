-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant C: DNA encoding preserves information.
--   two-bit mode: 00 ↦ A, 01 ↦ C, 10 ↦ G, 11 ↦ T (first bit high)
--   compatibility mode (JS DNA = ['A','T']): false (0) ↦ A, true (1) ↦ T
module DNA.Encoding where

open import Prelude

data Base : Set where
  A C G T : Base

enc2 : Bool → Bool → Base
enc2 false false = A
enc2 false true = C
enc2 true false = G
enc2 true true = T

dec2 : Base → Bool × Bool
dec2 A = false , false
dec2 C = false , true
dec2 G = true , false
dec2 T = true , true

dec-enc : (h l : Bool) → dec2 (enc2 h l) ≡ (h , l)
dec-enc false false = refl
dec-enc false true = refl
dec-enc true false = refl
dec-enc true true = refl

enc-dec : (n : Base) → enc2 (fst (dec2 n)) (snd (dec2 n)) ≡ n
enc-dec A = refl
enc-dec C = refl
enc-dec G = refl
enc-dec T = refl

-- Vector form with the even-length policy expressed in the type: 2n bits ↦ n bases.
encode : {n : Nat} → Vec (Bool × Bool) n → Vec Base n
encode [] = []
encode ((h , l) ∷ ps) = enc2 h l ∷ encode ps

decode : {n : Nat} → Vec Base n → Vec (Bool × Bool) n
decode [] = []
decode (b ∷ bs) = dec2 b ∷ decode bs

invariantC : {n : Nat} (ps : Vec (Bool × Bool) n) → decode (encode ps) ≡ ps
invariantC [] = refl
invariantC ((h , l) ∷ ps) = cong₂ _∷_ (dec-enc h l) (invariantC ps)

encode-decode : {n : Nat} (bs : Vec Base n) → encode (decode bs) ≡ bs
encode-decode [] = refl
encode-decode (b ∷ bs) = cong₂ _∷_ (enc-dec b) (encode-decode bs)

-- List form used by the runtimes: odd-length input is rejected (nothing), never truncated.
encodeBits : List Bool → Maybe (List Base)
encodeBits [] = just []
encodeBits (_ ∷ []) = nothing
encodeBits (h ∷ l ∷ rest) with encodeBits rest
... | nothing = nothing
... | just ns = just (enc2 h l ∷ ns)

decodeBases : List Base → List Bool
decodeBases [] = []
decodeBases (n ∷ ns) = fst (dec2 n) ∷ snd (dec2 n) ∷ decodeBases ns

encodeBits-sound : (bs : List Bool) (ns : List Base) → encodeBits bs ≡ just ns → decodeBases ns ≡ bs
encodeBits-sound [] .[] refl = refl
encodeBits-sound (_ ∷ []) ns ()
encodeBits-sound (h ∷ l ∷ rest) ns eq with encodeBits rest in er
encodeBits-sound (h ∷ l ∷ rest) ns () | nothing
encodeBits-sound (h ∷ l ∷ rest) .(enc2 h l ∷ ms) refl | just ms =
  cong₂ (λ p q → fst p ∷ snd p ∷ q) (dec-enc h l) (encodeBits-sound rest ms er)

data Even : Nat → Set where
  ev0 : Even zero
  ev2 : {n : Nat} → Even n → Even (suc (suc n))

encodeBits-complete : (bs : List Bool) → Even (length bs) → Σ (List Base) (λ ns → encodeBits bs ≡ just ns)
encodeBits-complete [] ev0 = [] , refl
encodeBits-complete (h ∷ l ∷ rest) (ev2 e) with encodeBits rest | encodeBits-complete rest e
... | just ms | _ , refl = (enc2 h l ∷ ms) , refl
... | nothing | _ , ()

compat : Bool → Base
compat false = A
compat true = T

compatDecode : Base → Maybe Bool
compatDecode A = just false
compatDecode T = just true
compatDecode C = nothing
compatDecode G = nothing

compat-roundtrip : (b : Bool) → compatDecode (compat b) ≡ just b
compat-roundtrip false = refl
compat-roundtrip true = refl
