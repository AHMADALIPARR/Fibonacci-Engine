-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant F: trace consistency. A trace accepted by the checker consists of legal transitions
-- from the specified initial configuration (and ends in a halting configuration).
module Turing.Trace where

open import Prelude
open import Turing.Machine

module Traces (M : Machine) where
  open Machine M
  open Semantics M

  -- Chain c cs: cs starts at c and every consecutive pair is a legal Step.
  data Chain : Config → List Config → Set where
    single : {c : Config} → Chain c (c ∷ [])
    extend : {c c' : Config} {cs : List Config} → Step c c' → Chain c' (c' ∷ cs) → Chain c (c ∷ c' ∷ cs)

  -- Recording runner: the history of configurations visited with a step budget (fuel).
  runTrace : Nat → Config → List Config
  runTrace zero c = c ∷ []
  runTrace (suc n) c with step c
  ... | nothing = c ∷ []
  ... | just c' = c ∷ runTrace n c'

  runTrace-head : (n : Nat) (c : Config) → Σ (List Config) (λ cs → runTrace n c ≡ c ∷ cs)
  runTrace-head zero c = [] , refl
  runTrace-head (suc n) c with step c
  ... | nothing = [] , refl
  ... | just c' = runTrace n c' , refl

  -- Every recorded run is a legal chain from its initial configuration.
  runTrace-legal : (n : Nat) (c : Config) → Chain c (runTrace n c)
  runTrace-legal zero c = single
  runTrace-legal (suc n) c with step c in eq
  ... | nothing = single
  ... | just c' with runTrace-head n c'
  ...   | cs , e = subst (λ t → Chain c (c ∷ t)) (sym e)
                         (extend (step-sound c c' eq) (subst (Chain c') e (runTrace-legal n c')))

  -- Decidable configuration equality, from the machine's sound symbol/state equalities.
  eqList : List Sym → List Sym → Bool
  eqList [] [] = true
  eqList (a ∷ as) (b ∷ bs) = eqSym a b ∧ eqList as bs
  eqList _ _ = false

  eqInt : Int → Int → Bool
  eqInt (+ m) (+ n) = m == n
  eqInt -[1+ m ] -[1+ n ] = m == n
  eqInt _ _ = false

  ∧-l : (a b : Bool) → (a ∧ b) ≡ true → a ≡ true
  ∧-l true b _ = refl

  ∧-r : (a b : Bool) → (a ∧ b) ≡ true → b ≡ true
  ∧-r true b p = p

  eqList-sound : (xs ys : List Sym) → eqList xs ys ≡ true → xs ≡ ys
  eqList-sound [] [] _ = refl
  eqList-sound (a ∷ as) (b ∷ bs) p =
    cong₂ _∷_ (eqSym-sound a b (∧-l (eqSym a b) _ p)) (eqList-sound as bs (∧-r (eqSym a b) _ p))
  eqList-sound [] (_ ∷ _) ()
  eqList-sound (_ ∷ _) [] ()

  eqInt-sound : (i j : Int) → eqInt i j ≡ true → i ≡ j
  eqInt-sound (+ m) (+ n) p = cong +_ (==-sound m n p)
  eqInt-sound -[1+ m ] -[1+ n ] p = cong -[1+_] (==-sound m n p)
  eqInt-sound (+ _) -[1+ _ ] ()
  eqInt-sound -[1+ _ ] (+ _) ()

  eqConfig : Config → Config → Bool
  eqConfig (conf q l x r p) (conf q' l' x' r' p') =
    eqState q q' ∧ (eqList l l' ∧ (eqSym x x' ∧ (eqList r r' ∧ eqInt p p')))

  eqConfig-sound : (a b : Config) → eqConfig a b ≡ true → a ≡ b
  eqConfig-sound (conf q l x r p) (conf q' l' x' r' p') e
    with eqState q q' in e1 | eqList l l' in e2 | eqSym x x' in e3 | eqList r r' in e4 | eqInt p p' in e5
  ... | true | true | true | true | true
    rewrite eqState-sound q q' e1 | eqList-sound l l' e2 | eqSym-sound x x' e3
          | eqList-sound r r' e4 | eqInt-sound p p' e5 = refl
  eqConfig-sound _ _ () | false | _ | _ | _ | _
  eqConfig-sound _ _ () | true | false | _ | _ | _
  eqConfig-sound _ _ () | true | true | false | _ | _
  eqConfig-sound _ _ () | true | true | true | false | _
  eqConfig-sound _ _ () | true | true | true | true | false

  -- Trace checker: re-executes every transition and compares it with the recorded next configuration.
  checkLinks : Config → List Config → Bool
  checkLinks d [] = true
  checkLinks d (e ∷ es) with step d
  ... | nothing = false
  ... | just d' = eqConfig d' e ∧ checkLinks e es

  checkChain : Config → List Config → Bool
  checkChain c [] = false
  checkChain c (d ∷ ds) = eqConfig c d ∧ checkLinks d ds

  checkLinks-sound : (d : Config) (es : List Config) → checkLinks d es ≡ true → Chain d (d ∷ es)
  checkLinks-sound d [] _ = single
  checkLinks-sound d (e ∷ es) p with step d in st
  ... | just d' with eqConfig d' e in q
  ...   | true = extend (step-sound d e (trans st (cong just (eqConfig-sound d' e q)))) (checkLinks-sound e es p)

  checkChain-sound : (c : Config) (cs : List Config) → checkChain c cs ≡ true → Chain c cs
  checkChain-sound c [] ()
  checkChain-sound c (d ∷ ds) p with eqConfig c d in q
  ... | true rewrite eqConfig-sound c d q = checkLinks-sound d ds p

  last : Config → List Config → Config
  last c [] = c
  last c (d ∷ ds) = last d ds

  -- Accepted = legal chain from the initial configuration that ends in a halting state.
  accepts : Config → List Config → Bool
  accepts c cs = checkChain c cs ∧ isHalt (state (last c cs))

  invariantF : (c : Config) (cs : List Config) → accepts c cs ≡ true →
               Chain c cs × (isHalt (state (last c cs)) ≡ true)
  invariantF c cs p = checkChain-sound c cs (∧-l (checkChain c cs) _ p) , ∧-r (checkChain c cs) _ p
