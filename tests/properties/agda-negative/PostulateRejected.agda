-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- EXPECTED TO FAIL: a postulate is rejected under --safe.
module PostulateRejected where

open import Prelude

postulate
  anything : (n : Nat) → n ≡ suc n
