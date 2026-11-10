# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# Fibonacci words over {0,1}: W0 = ⟨0⟩, W1 = ⟨0,1⟩, W(n+2) = W(n+1) ∾ W(n).
# Same recurrence and bounds as fibonacciWords in the original fibonacci_braid.js.

# Words n: list W0 … W(n-1). JS-compatible bound 2 ≤ n ≤ 24.
Words ⇐ {
  "count must be an integer in 2..24" ! (𝕩=⌊𝕩) ∧ (2≤𝕩) ∧ 𝕩≤24
  ws ← {𝕩 ∾ <(¯1⊑𝕩) ∾ ¯2⊑𝕩}⍟(𝕩-2) ⟨⟨0⟩, 0‿1⟩
  "length recurrence" ! ∧´ (2↓≠¨ws) = (1↓¯1↓≠¨ws) + ¯2↓≠¨ws
  "prefix property" ! ∧´ (1↓¯1↓ws) {𝕨≡(≠𝕨)↑𝕩}¨ 2↓ws
  ws
}

# Bounded generator: W0 … W(n-1) for any n ≥ 1 whose last word has length ≤ 𝕨.
WordsBounded ⇐ {lim 𝕊 n:
  "count must be ≥ 1" ! (n=⌊n) ∧ n≥1
  "length bound exceeded" ! lim ≥ Length n-1
  n ↑ {𝕩 ∾ <(¯1⊑𝕩) ∾ ¯2⊑𝕩}⍟(0⌈n-2) ⟨⟨0⟩, 0‿1⟩
}

Word ⇐ {¯1⊑ 1e7 WordsBounded 𝕩+1}

# |W n| by the length recurrence (equals F(n+2)).
Length ⇐ {⊑ {⟨1⊑𝕩, +´𝕩⟩}⍟𝕩 1‿2}

# Fibonacci numbers F(0)=0, F(1)=1, … as a list of the first 𝕩 values.
Fibs ⇐ {𝕩 ↑ {𝕩∾+´¯2↑𝕩}⍟(0⌈𝕩-2) 0‿1}

# Symbol at index 𝕩 of W 𝕨, by descending the recurrence without building the word.
Index ⇐ {n 𝕊 i:
  "index out of range" ! (i≥0) ∧ i < Length n
  {
    0=⊑𝕩 ? 0 ;
    1=⊑𝕩 ? 1⊑𝕩 ;
    k‿j ← 𝕩 ⋄ l ← Length k-1
    𝕊 (j<l) ⊑ ⟨⟨k-2, j-l⟩, ⟨k-1, j⟩⟩
  } n‿i
}
