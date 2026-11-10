-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Invariant G: square-spiral (Ulam) indexing on Z². For every index n, index (position n) ≡ n;
-- hence position is injective and, restricted to Fin N, every valid index maps to exactly one
-- position and the inverse recovers it. Universal over all n and all N (no bound).
-- Pure index arithmetic; this is not a physical simulation of anything.
module Spiral.Index where

open import Prelude

dbl : Nat → Nat
dbl zero = zero
dbl (suc n) = suc (suc (dbl n))

-- Ring r = suc k has four sides of w k = 2r cells.
w : Nat → Nat
w k = dbl (suc k)

data RC : Set where
  origin : RC
  ring   : (k : Nat) → Fin 4 → Fin (w k) → RC

mulN : Nat → Nat → Nat
mulN zero _ = zero
mulN (suc s) x = x + mulN s x

-- Number of indices before ring k+1 (equals (2k+1)²; see Spiral.Vectors for the evaluated check).
before : Nat → Nat
before zero = 1
before (suc k) = before k + mulN 4 (w k)

fromRC : RC → Nat
fromRC origin = zero
fromRC (ring k s t) = before k + (mulN (toNat s) (w k) + toNat t)

incFin : {n : Nat} → Fin n → Maybe (Fin n)
incFin {suc zero} zero = nothing
incFin {suc zero} (suc ())
incFin {suc (suc n)} zero = just (suc zero)
incFin {suc (suc n)} (suc i) with incFin i
... | nothing = nothing
... | just j = just (suc j)

incFin-just : {n : Nat} (i j : Fin n) → incFin i ≡ just j → toNat j ≡ suc (toNat i)
incFin-just {suc zero} zero j ()
incFin-just {suc zero} (suc ()) j
incFin-just {suc (suc n)} zero .(suc zero) refl = refl
incFin-just {suc (suc n)} (suc i) j e with incFin i in ei
incFin-just {suc (suc n)} (suc i) .(suc j') refl | just j' = cong suc (incFin-just i j' ei)

incFin-nothing : {n : Nat} (i : Fin n) → incFin i ≡ nothing → suc (toNat i) ≡ n
incFin-nothing {suc zero} zero _ = refl
incFin-nothing {suc zero} (suc ())
incFin-nothing {suc (suc n)} zero ()
incFin-nothing {suc (suc n)} (suc i) e with incFin i in ei
... | nothing = cong suc (incFin-nothing i ei)

nextRC : RC → RC
nextRC origin = ring zero zero zero
nextRC (ring k s t) with incFin t
... | just t' = ring k s t'
... | nothing with incFin s
...   | just s' = ring k s' zero
...   | nothing = ring (suc k) zero zero

toRC : Nat → RC
toRC zero = origin
toRC (suc n) = nextRC (toRC n)

key : (b m W tn : Nat) → suc tn ≡ W → b + ((W + m) + zero) ≡ suc (b + (m + tn))
key b m .(suc tn) tn refl =
  trans (cong (λ z → b + z) (+-zero (suc tn + m)))
        (trans (+-suc b (tn + m)) (cong (λ z → suc (b + z)) (+-comm tn m)))

fromRC-next : (c : RC) → fromRC (nextRC c) ≡ suc (fromRC c)
fromRC-next origin = refl
fromRC-next (ring k s t) with incFin t in et
... | just t' rewrite incFin-just t t' et =
      trans (cong (λ z → before k + z) (+-suc (mulN (toNat s) (w k)) (toNat t)))
            (+-suc (before k) (mulN (toNat s) (w k) + toNat t))
... | nothing with incFin s in es
...   | just s' rewrite incFin-just s s' es =
        key (before k) (mulN (toNat s) (w k)) (w k) (toNat t) (incFin-nothing t et)
...   | nothing with suc-inj (incFin-nothing s es)
...     | e3 rewrite +-assoc (before k) (mulN 4 (w k)) zero | e3 =
          key (before k) (mulN 3 (w k)) (w k) (toNat t) (incFin-nothing t et)

fromRC-toRC : (n : Nat) → fromRC (toRC n) ≡ n
fromRC-toRC zero = refl
fromRC-toRC (suc n) = trans (fromRC-next (toRC n)) (cong suc (fromRC-toRC n))

-- Integer helpers
_⊖_ : Nat → Nat → Int
m ⊖ zero = + m
zero ⊖ suc n = -[1+ n ]
suc m ⊖ suc n = m ⊖ n

abs : Int → Nat
abs (+ n) = n
abs -[1+ n ] = suc n

eqI : Int → Int → Bool
eqI (+ m) (+ n) = m == n
eqI -[1+ m ] -[1+ n ] = m == n
eqI _ _ = false

_+N_ : Int → Nat → Nat
(+ n) +N k = n + k
-[1+ n ] +N k = k - suc n

_-I_ : Nat → Int → Nat
k -I (+ n) = k - n
k -I -[1+ n ] = k + suc n

max : Nat → Nat → Nat
max a b = if a < b then b else a

clamp : Nat → (m : Nat) → Fin (suc m)
clamp zero m = zero
clamp (suc n) zero = zero
clamp (suc n) (suc m) = suc (clamp n m)

clamp-toNat : {m : Nat} (t : Fin (suc m)) → clamp (toNat t) m ≡ t
clamp-toNat zero = refl
clamp-toNat {suc m} (suc t) = cong suc (clamp-toNat t)

Coord : Set
Coord = Int × Int

placeSide : (k : Nat) → Fin 4 → Nat → Coord
placeSide k zero tn = + suc k , tn ⊖ k
placeSide k (suc zero) tn = k ⊖ tn , + suc k
placeSide k (suc (suc zero)) tn = -[1+ k ] , k ⊖ tn
placeSide k (suc (suc (suc zero))) tn = tn ⊖ k , -[1+ k ]

place : RC → Coord
place origin = + 0 , + 0
place (ring k s t) = placeSide k s (toNat t)

s1 s2 s3 : Fin 4
s1 = suc zero
s2 = suc (suc zero)
s3 = suc (suc (suc zero))

go : Nat → Int → Int → RC
go zero x y = origin
go (suc k) x y =
  if eqI x (+ suc k) ∧ not (eqI y -[1+ k ]) then ring k zero (clamp (y +N k) (suc (dbl k)))
  else if eqI y (+ suc k) then ring k s1 (clamp (k -I x) (suc (dbl k)))
  else if eqI x -[1+ k ] then ring k s2 (clamp (k -I y) (suc (dbl k)))
  else ring k s3 (clamp (x +N k) (suc (dbl k)))

unplace : Coord → RC
unplace (x , y) = go (max (abs x) (abs y)) x y

-- Arithmetic lemmas
ne1 : (n j : Nat) → (n == suc (n + j)) ≡ false
ne1 zero j = refl
ne1 (suc n) j = ne1 n j

plus-minus : (n j : Nat) → (n + j) - n ≡ j
plus-minus zero j = refl
plus-minus (suc n) j = plus-minus n j

monus-≤ : (a b : Nat) → (a - b) ≤ a
monus-≤ zero zero = z≤n
monus-≤ zero (suc b) = z≤n
monus-≤ (suc a) zero = ≤-refl (suc a)
monus-≤ (suc a) (suc b) = ≤-step (monus-≤ a b)

monus-bound : (t k j : Nat) → t ≤ (k + j) → (t - k) ≤ j
monus-bound zero zero j _ = z≤n
monus-bound zero (suc k) j _ = z≤n
monus-bound (suc t) zero j p = p
monus-bound (suc t) (suc k) j (s≤s p) = monus-bound t k j p

dbl-+ : (k : Nat) → dbl k ≡ k + k
dbl-+ zero = refl
dbl-+ (suc k) = cong suc (trans (cong suc (dbl-+ k)) (sym (+-suc k k)))

≤-pred : {m n : Nat} → suc m ≤ suc n → m ≤ n
≤-pred (s≤s p) = p

≤-trans : {a b c : Nat} → a ≤ b → b ≤ c → a ≤ c
≤-trans z≤n _ = z≤n
≤-trans (s≤s p) (s≤s q) = s≤s (≤-trans p q)

⊖-≥ : (m n : Nat) → n ≤ m → m ⊖ n ≡ + (m - n)
⊖-≥ m zero _ = refl
⊖-≥ (suc m) (suc n) (s≤s p) = ⊖-≥ m n p

⊖-< : (m n : Nat) → suc m ≤ n → m ⊖ n ≡ -[1+ (n - suc m) ]
⊖-< zero (suc n) _ = refl
⊖-< (suc m) (suc n) (s≤s p) = ⊖-< m n p

-- |t ⊖ k| ≤ k+1 and |k ⊖ t| ≤ k+1 whenever t ≤ 2k+1.
bound1 : (t k : Nat) → t ≤ suc (dbl k) → abs (t ⊖ k) ≤ suc k
bound1 t k p with t < k in c
... | true rewrite ⊖-< t k (<→≤ t k c) = s≤s (monus-≤ k (suc t))
... | false rewrite ⊖-≥ t k (¬<→≤ t k c) =
      monus-bound t k (suc k) (subst (t ≤_) (trans (cong suc (dbl-+ k)) (sym (+-suc k k))) p)

bound2 : (t k : Nat) → t ≤ suc (dbl k) → abs (k ⊖ t) ≤ suc k
bound2 t k p with k < t in c
... | true rewrite ⊖-< k t (<→≤ k t c) =
      s≤s (monus-bound t (suc k) k (subst (t ≤_) (cong suc (dbl-+ k)) p))
... | false rewrite ⊖-≥ k t (¬<→≤ k t c) = ≤-step (monus-≤ k t)

max-l : (a b : Nat) → b ≤ a → max a b ≡ a
max-l a b p with a < b in c
... | false = refl
... | true = ⊥-elim (true≢false (trans (sym c) (≤→¬> p)))

max-r : (a b : Nat) → a ≤ b → max a b ≡ b
max-r a b p with a < b in c
... | true = refl
... | false = ≤-antisym p (¬<→≤ a b c)

-- Equality tests used by unplace
L2g : (t k j : Nat) → eqI (t ⊖ k) -[1+ (k + j) ] ≡ false
L2g t zero j = refl
L2g zero (suc n) j = ne1 n j
L2g (suc t) (suc k) j rewrite sym (+-suc k j) = L2g t k (suc j)

L2 : (t k : Nat) → eqI (t ⊖ k) -[1+ k ] ≡ false
L2 t k = subst (λ m → eqI (t ⊖ k) -[1+ m ] ≡ false) (+-zero k) (L2g t k zero)

L4g : (k t j : Nat) → eqI (k ⊖ t) (+ suc (k + j)) ≡ false
L4g k zero j = ne1 k j
L4g zero (suc n) j = refl
L4g (suc k) (suc t) j rewrite sym (+-suc k j) = L4g k t (suc j)

L4 : (k t : Nat) → eqI (k ⊖ t) (+ suc k) ≡ false
L4 k t = subst (λ m → eqI (k ⊖ t) (+ suc m) ≡ false) (+-zero k) (L4g k t zero)

L3g : (t k j : Nat) → (t ⊖ k) +N (k + j) ≡ t + j
L3g t zero j = refl
L3g zero (suc n) j = plus-minus n j
L3g (suc t) (suc k) j rewrite sym (+-suc k j) | sym (+-suc t j) = L3g t k (suc j)

L3 : (t k : Nat) → (t ⊖ k) +N k ≡ t
L3 t k = trans (subst (λ m → (t ⊖ k) +N m ≡ (t ⊖ k) +N (k + zero)) (+-zero k) refl)
               (trans (L3g t k zero) (+-zero t))

L5g : (k t j : Nat) → (k + j) -I (k ⊖ t) ≡ t + j
L5g k zero j = plus-minus k j
L5g zero (suc n) j = +-comm j (suc n)
L5g (suc k) (suc t) j rewrite sym (+-suc k j) | sym (+-suc t j) = L5g k t (suc j)

L5 : (k t : Nat) → k -I (k ⊖ t) ≡ t
L5 k t = trans (subst (λ m → m -I (k ⊖ t) ≡ (k + zero) -I (k ⊖ t)) (+-zero k) refl)
               (trans (L5g k t zero) (+-zero t))

∧-false : (b : Bool) → (b ∧ false) ≡ false
∧-false true = refl
∧-false false = refl

tbound : (k : Nat) (t : Fin (w k)) → toNat t ≤ suc (dbl k)
tbound k t = ≤-pred (toNat-< t)

fin-eq : (k : Nat) (t : Fin (w k)) (n : Nat) → n ≡ toNat t → clamp n (suc (dbl k)) ≡ t
fin-eq k t .(toNat t) refl = clamp-toNat t

unplace-place : (c : RC) → unplace (place c) ≡ c
unplace-place origin = refl
unplace-place (ring k zero t)
  rewrite max-l (suc k) (abs (toNat t ⊖ k)) (bound1 (toNat t) k (tbound k t))
        | ==-refl k | L2 (toNat t) k
  = cong (ring k zero) (fin-eq k t _ (L3 (toNat t) k))
unplace-place (ring k (suc zero) t)
  rewrite max-r (abs (k ⊖ toNat t)) (suc k) (bound2 (toNat t) k (tbound k t))
        | L4 k (toNat t) | ==-refl k
  = cong (ring k s1) (fin-eq k t _ (L5 k (toNat t)))
unplace-place (ring k (suc (suc zero)) t)
  rewrite max-l (suc k) (abs (k ⊖ toNat t)) (bound2 (toNat t) k (tbound k t))
        | L4 k (toNat t) | ==-refl k
  = cong (ring k s2) (fin-eq k t _ (L5 k (toNat t)))
unplace-place (ring k (suc (suc (suc zero))) t)
  rewrite max-r (abs (toNat t ⊖ k)) (suc k) (bound1 (toNat t) k (tbound k t))
        | ==-refl k | ∧-false (eqI (toNat t ⊖ k) (+ suc k)) | L2 (toNat t) k
  = cong (ring k s3) (fin-eq k t _ (L3 (toNat t) k))
unplace-place (ring k (suc (suc (suc (suc ())))) t)

position : Nat → Coord
position n = place (toRC n)

index : Coord → Nat
index p = fromRC (unplace p)

-- Invariant G (inverse recovers the original index), for every n.
invariantG : (n : Nat) → index (position n) ≡ n
invariantG n = trans (cong fromRC (unplace-place (toRC n))) (fromRC-toRC n)

position-injective : (i j : Nat) → position i ≡ position j → i ≡ j
position-injective i j e = trans (sym (invariantG i)) (trans (cong index e) (invariantG j))

-- Dependent-type form for the first N indices.
positionFin : {N : Nat} → Fin N → Coord
positionFin i = position (toNat i)

fromℕ< : (n : Nat) {N : Nat} → suc n ≤ N → Fin N
fromℕ< zero (s≤s _) = zero
fromℕ< (suc n) (s≤s p) = suc (fromℕ< n p)

fromℕ<-toNat : {N : Nat} (n : Nat) (p : suc n ≤ N) (i : Fin N) → n ≡ toNat i → fromℕ< n p ≡ i
fromℕ<-toNat zero (s≤s _) zero refl = refl
fromℕ<-toNat (suc n) (s≤s p) (suc i) e = cong suc (fromℕ<-toNat n p i (suc-inj e))
fromℕ<-toNat zero (s≤s _) (suc i) ()
fromℕ<-toNat (suc n) (s≤s _) zero ()

valid : {N : Nat} (i : Fin N) → suc (index (positionFin i)) ≤ N
valid {N} i = subst (λ m → suc m ≤ N) (sym (invariantG (toNat i))) (toNat-< i)

indexFin : {N : Nat} (p : Coord) → suc (index p) ≤ N → Fin N
indexFin p v = fromℕ< (index p) v

invariantG-Fin : {N : Nat} (i : Fin N) → indexFin (positionFin i) (valid i) ≡ i
invariantG-Fin i = fromℕ<-toNat _ (valid i) i (invariantG (toNat i))

toNat-inj : {N : Nat} (i j : Fin N) → toNat i ≡ toNat j → i ≡ j
toNat-inj zero zero _ = refl
toNat-inj (suc i) (suc j) e = cong suc (toNat-inj i j (suc-inj e))
toNat-inj zero (suc j) ()
toNat-inj (suc i) zero ()

-- Every valid index maps to exactly one position, and distinct valid indices to distinct positions.
positionFin-injective : {N : Nat} (i j : Fin N) → positionFin i ≡ positionFin j → i ≡ j
positionFin-injective i j e = toNat-inj i j (position-injective (toNat i) (toNat j) e)
