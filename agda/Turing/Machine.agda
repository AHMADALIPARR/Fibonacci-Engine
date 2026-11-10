-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant E: deterministic next-step behaviour for machines with a functional transition table.
-- Configuration = control state, tape (zipper: reversed left part, scanned cell, right part),
-- head position (integer), and the machine's transition relation.
module Turing.Machine where

open import Prelude

data Move : Set where
  L R S : Move

record Machine : Set₁ where
  field
    State Sym : Set
    blank : Sym
    isHalt : State → Bool
    δ : State → Sym → Maybe (Sym × (Move × State))
    eqState : State → State → Bool
    eqState-sound : (p q : State) → eqState p q ≡ true → p ≡ q
    eqSym : Sym → Sym → Bool
    eqSym-sound : (a b : Sym) → eqSym a b ≡ true → a ≡ b

module Semantics (M : Machine) where
  open Machine M

  sucI : Int → Int
  sucI (+ n) = + suc n
  sucI -[1+ zero ] = + zero
  sucI -[1+ suc n ] = -[1+ n ]

  predI : Int → Int
  predI (+ zero) = -[1+ zero ]
  predI (+ suc n) = + n
  predI -[1+ n ] = -[1+ suc n ]

  record Config : Set where
    constructor conf
    field
      state : State
      left  : List Sym
      cur   : Sym
      right : List Sym
      pos   : Int
  open Config public

  shift : Move → Config → Config
  shift S c = c
  shift L (conf q [] x r p) = conf q [] blank (x ∷ r) (predI p)
  shift L (conf q (l ∷ ls) x r p) = conf q ls l (x ∷ r) (predI p)
  shift R (conf q l x [] p) = conf q (x ∷ l) blank [] (sucI p)
  shift R (conf q l x (r ∷ rs) p) = conf q (x ∷ l) r rs (sucI p)

  apply : Config → Sym → Move → State → Config
  apply (conf _ l _ r p) w m q' = shift m (conf q' l w r p)

  -- The transition relation induced by the table.
  Rule : State → Sym → Sym → Move → State → Set
  Rule q s w m q' = δ q s ≡ just (w , (m , q'))

  data Step (c c' : Config) : Set where
    rule : {w : Sym} {m : Move} {q' : State} →
           isHalt (state c) ≡ false → Rule (state c) (cur c) w m q' → apply c w m q' ≡ c' → Step c c'

  -- Invariant E: next-step determinism.
  step-deterministic : {c c1 c2 : Config} → Step c c1 → Step c c2 → c1 ≡ c2
  step-deterministic (rule _ d1 refl) (rule _ d2 refl) with trans (sym d1) d2
  ... | refl = refl

  -- Executable step function and its agreement with the relation.
  step : Config → Maybe Config
  step c with isHalt (state c)
  ... | true = nothing
  ... | false with δ (state c) (cur c)
  ...   | nothing = nothing
  ...   | just (w , (m , q')) = just (apply c w m q')

  step-sound : (c c' : Config) → step c ≡ just c' → Step c c'
  step-sound c c' eq with isHalt (state c) in h
  ... | false with δ (state c) (cur c) in d
  ...   | just (w , (m , q')) = rule h d (just-inj eq)

  step-complete : {c c' : Config} → Step c c' → step c ≡ just c'
  step-complete {c} (rule {w} {m} {q'} h d refl) with isHalt (state c) | h
  ... | false | refl with δ (state c) (cur c) | d
  ...   | just _ | refl = refl

  halted-no-step : (c : Config) → isHalt (state c) ≡ true → (c' : Config) → ¬ Step c c'
  halted-no-step c h c' (rule h' _ _) = true≢false (trans (sym h) h')

  -- Determinism for ANY functional transition relation (not only one given as a function).
  Functional : (State → Sym → Sym → Move → State → Set) → Set
  Functional Rel = {q : State} {s w w' : Sym} {m m' : Move} {q' q'' : State} →
                   Rel q s w m q' → Rel q s w' m' q'' → (w ≡ w') × ((m ≡ m') × (q' ≡ q''))

  data StepR (Rel : State → Sym → Sym → Move → State → Set) (c c' : Config) : Set where
    ruleR : {w : Sym} {m : Move} {q' : State} → Rel (state c) (cur c) w m q' → apply c w m q' ≡ c' → StepR Rel c c'

  stepR-deterministic : (Rel : State → Sym → Sym → Move → State → Set) → Functional Rel →
                        {c c1 c2 : Config} → StepR Rel c c1 → StepR Rel c c2 → c1 ≡ c2
  stepR-deterministic Rel fun (ruleR r1 refl) (ruleR r2 refl) with fun r1 r2
  ... | refl , (refl , refl) = refl

  -- The table-induced relation is functional (the hypothesis is verified, not assumed).
  rule-functional : Functional Rule
  rule-functional d1 d2 with trans (sym d1) d2
  ... | refl = refl , (refl , refl)
