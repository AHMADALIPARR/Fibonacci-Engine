-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- EXPECTED TO FAIL: claims the increment machine takes 10 steps on 1011 (the JS oracle says 8).
-- Kept to show the type checker rejects a false computational claim.
module WrongStepCount where

open import Prelude
open import Turing.Increment

wrong : length trace ≡ 11
wrong = refl
