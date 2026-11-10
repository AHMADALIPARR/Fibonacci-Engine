-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- EXPECTED TO FAIL: braid is not an involution; this false theorem cannot be proved.
module InvolutionFalse where

open import Prelude
open import Braid.XorBraid

involution : (x y : Vec Bool 1) → braid (braid (x , y)) ≡ (x , y)
involution x y = refl
