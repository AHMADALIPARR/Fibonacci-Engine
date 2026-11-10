// SPDX-License-Identifier: AGPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
module dna_encoding

// Two-bit DNA encoding 00->A, 01->C, 10->G, 11->T and the compatibility map 0->A, 1->T.
// Bounded check that the encoding is a bijection between bit pairs and bases.

abstract sig Bit {}
one sig Zero, One extends Bit {}

abstract sig Base {}
one sig A, C, G, T extends Base {}

fun enc[h, l: Bit]: one Base {
  (h = Zero and l = Zero) => A else
  (h = Zero and l = One)  => C else
  (h = One  and l = Zero) => G else T
}

fun decHi[n: Base]: one Bit { (n in A + C) => Zero else One }
fun decLo[n: Base]: one Bit { (n in A + G) => Zero else One }

fun compat[b: Bit]: one Base { (b = Zero) => A else T }

assert DecodeEncode { all h, l: Bit | decHi[enc[h, l]] = h and decLo[enc[h, l]] = l }
assert EncodeDecode { all n: Base | enc[decHi[n], decLo[n]] = n }
assert Injective { all h1, l1, h2, l2: Bit | enc[h1, l1] = enc[h2, l2] implies (h1 = h2 and l1 = l2) }
assert CompatInjective { all b1, b2: Bit | compat[b1] = compat[b2] implies b1 = b2 }

// A tempting but wrong claim: that the compatibility map is onto the four bases.
assert CompatOnto { all n: Base | some b: Bit | compat[b] = n }

check DecodeEncode expect 0
check EncodeDecode expect 0
check Injective expect 0
check CompatInjective expect 0
check CompatOnto expect 1
