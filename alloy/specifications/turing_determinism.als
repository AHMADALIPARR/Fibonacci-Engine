// SPDX-License-Identifier: AGPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
module turing_determinism

// Turing-machine configurations with a functional transition table (at most one rule per
// state/symbol pair). Bounded check that the next-step relation is deterministic, and that dropping
// functionality breaks determinism (counterexample expected).

sig State {}
sig Sym {}
abstract sig Move {}
one sig L, R, S extends Move {}

sig Rule {
  from: one State,
  read: one Sym,
  write: one Sym,
  mv: one Move,
  to: one State
}

sig Cell { left: lone Cell }

sig Config {
  st: one State,
  hd: one Cell,
  tape: Cell -> lone Sym
}

pred functional { all r1, r2: Rule | (r1.from = r2.from and r1.read = r2.read) implies r1 = r2 }

pred applies[r: Rule, c: Config] { r.from = c.st and r.read = c.hd.(c.tape) }

pred next[c, c2: Config] {
  some r: Rule | applies[r, c] and {
    c2.st = r.to
    c2.tape = c.tape ++ (c.hd -> r.write)
    r.mv = S implies c2.hd = c.hd
    r.mv = L implies c2.hd = c.hd.left
    r.mv = R implies c2.hd.left = c.hd
  }
}

fact cellsLinear {
  no c: Cell | c in c.^left
  all c: Cell | lone left.c
}

assert Deterministic {
  functional implies all c, c1, c2: Config | (next[c, c1] and next[c, c2]) implies
    (c1.st = c2.st and c1.hd = c2.hd and c1.tape = c2.tape)
}

assert DeterministicWithoutFunctionality {
  all c, c1, c2: Config | (next[c, c1] and next[c, c2]) implies
    (c1.st = c2.st and c1.hd = c2.hd and c1.tape = c2.tape)
}

check Deterministic for 4 expect 0
check DeterministicWithoutFunctionality for 4 expect 1
