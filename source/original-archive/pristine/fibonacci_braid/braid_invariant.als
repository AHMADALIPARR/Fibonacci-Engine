module braid_invariant

// A finite relational proof obligation for the reversible two-lane braid.
// Alloy explores every assignment of binary inputs at the specified scope.

abstract sig Bit {}
one sig Zero, One extends Bit {}

sig Pos {}

one sig Braid {
  x: Pos -> one Bit,
  y: Pos -> one Bit,
  a: Pos -> one Bit,
  b: Pos -> one Bit
}

fun bitxor[u, v: Bit]: one Bit {
  (u = v) => Zero else One
}

fact BraidTransition {
  all p: Pos | {
    p.(Braid.a) = p.(Braid.y)
    p.(Braid.b) = bitxor[p.(Braid.x), p.(Braid.y)]
  }
}

assert Reversible {
  all p: Pos | {
    p.(Braid.x) = bitxor[p.(Braid.a), p.(Braid.b)]
    p.(Braid.y) = p.(Braid.a)
  }
}

// Alloy Analyzer: expect no counterexample for any finite scope.
check Reversible for exactly 8 Pos
run {} for exactly 8 Pos
