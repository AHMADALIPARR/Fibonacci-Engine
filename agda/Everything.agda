-- SPDX-License-Identifier: AGPL-3.0-only
-- This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
{-# OPTIONS --safe --without-K #-}
-- Imports every proof module; `agda Everything.agda` type-checks the whole development.
module Everything where

import Prelude
import Fibonacci.Words        -- Invariant A
import Braid.XorBraid         -- Invariant B
import Braid.AlloyReversible  -- Alloy braid_invariant.als, universal translation
import DNA.Encoding           -- Invariant C
import Coding.Repetition      -- Invariant D
import Turing.Machine         -- Invariant E
import Turing.Trace           -- Invariant F
import Turing.Increment       -- complete TM example (JS incrementRules) evaluated in Agda
import Spiral.Index           -- Invariant G
import Spiral.Vectors         -- Ruby ↔ Agda spiral cross-check
