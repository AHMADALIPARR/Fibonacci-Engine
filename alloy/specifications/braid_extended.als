// SPDX-License-Identifier: AGPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
module braid_extended

// Extends the original braid_invariant.als (kept verbatim alongside) with the second inverse
// direction, an intentionally false involution claim (to exercise counterexample generation), and an
// Alloy 6 temporal model showing the braid map has order 3: B(B(B(x,y))) = (x,y).
// All results are BOUNDED: they hold for the stated scopes only. Universal statements are in agda/.

abstract sig Bit {}
one sig Zero, One extends Bit {}

sig Pos {}

fun bitxor[u, v: Bit]: one Bit { (u = v) => Zero else One }

one sig Lanes {
  x: Pos -> one Bit,
  y: Pos -> one Bit,
  a: Pos -> one Bit,
  b: Pos -> one Bit,
  u: Pos -> one Bit,
  v: Pos -> one Bit
}

// (a, b) = B(x, y)  and  (u, v) = B(a, b)
fact Transitions {
  all p: Pos | {
    p.(Lanes.a) = p.(Lanes.y)
    p.(Lanes.b) = bitxor[p.(Lanes.x), p.(Lanes.y)]
    p.(Lanes.u) = p.(Lanes.b)
    p.(Lanes.v) = bitxor[p.(Lanes.a), p.(Lanes.b)]
  }
}

// B^-1(B(x,y)) = (x,y)
assert LeftInverse {
  all p: Pos | p.(Lanes.x) = bitxor[p.(Lanes.a), p.(Lanes.b)] and p.(Lanes.y) = p.(Lanes.a)
}

// B(B^-1(a,b)) = (a,b): with x' = a xor b, y' = a, B(x',y') = (a, (a xor b) xor a) = (a, b)
assert RightInverse {
  all p: Pos | let xp = bitxor[p.(Lanes.a), p.(Lanes.b)], yp = p.(Lanes.a) |
    yp = p.(Lanes.a) and bitxor[xp, yp] = p.(Lanes.b)
}

// FALSE claim, kept on purpose: "B is an involution" (B(B(x,y)) = (x,y)). Alloy must find a counterexample.
assert InvolutionClaim {
  all p: Pos | p.(Lanes.u) = p.(Lanes.x) and p.(Lanes.v) = p.(Lanes.y)
}

check LeftInverse for exactly 8 Pos expect 0
check RightInverse for exactly 8 Pos expect 0
check InvolutionClaim for exactly 1 Pos expect 1

// Temporal model (Alloy 6): one mutable lane pair, each step applies B.
one sig State {
  var sx: Pos -> one Bit,
  var sy: Pos -> one Bit
}

fact BraidSteps {
  always all p: Pos | {
    p.(State.sx') = p.(State.sy)
    p.(State.sy') = bitxor[p.(State.sx), p.(State.sy)]
  }
}

assert OrderThree {
  always all p: Pos | p.(State.sx''') = p.(State.sx) and p.(State.sy''') = p.(State.sy)
}

assert OrderNotOne {
  always all p: Pos | p.(State.sx') = p.(State.sx) and p.(State.sy') = p.(State.sy)
}

check OrderThree for exactly 4 Pos, 1..12 steps expect 0
check OrderNotOne for exactly 1 Pos, 1..4 steps expect 1
