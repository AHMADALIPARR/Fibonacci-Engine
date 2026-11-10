# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
#
# CBQN micro-benchmarks. Usage: bqn arrays/bench.bqn [samples]   (run from cbqn/)
# Prints one line per measurement:  name<TAB>median_seconds<TAB>min_seconds<TAB>elements<TAB>samples
# Each sample is the mean of `inner` repetitions timed with •_timed. Workloads are fixed (seeded •MakeRand).
br ← •Import "../braid/braid.bqn"
arr ← •Import "arrays.bqn"
sp ← •Import "../spiral/spiral.bqn"
fib ← •Import "../fibonacci/fibonacci.bqn"

samples ← {0=≠𝕩 ? 7 ; •ParseFloat ⊑𝕩} •args
r ← •MakeRand 20261110
n ← 1048576
x ← r.Range⟜2 n
y ← r.Range⟜2 n
rows ← 256 ⋄ cols ← 4096
mx ← rows‿cols ⥊ r.Range⟜2 rows×cols
my ← rows‿cols ⥊ r.Range⟜2 rows×cols
k ← 8 ⋄ w ← 131072
st ← k‿w ⥊ r.Range⟜2 k×w
prog ← ⟨⟨'P', 3‿0‿7‿1‿6‿2‿5‿4⟩, ⟨'X', 0‿5⟩, ⟨'S', ⟨2⟩⟩, ⟨'X', 6‿1⟩, ⟨'s', ⟨4⟩⟩, ⟨'P', 1‿2‿3‿4‿5‿6‿7‿0⟩⟩
inv ← br.InverseProgram prog
sym ← "ACGT" ⊏˜ r.Range⟜4 n
fa ← r.Range⟜0 n ⋄ fb ← r.Range⟜0 n ⋄ fc ← r.Range⟜0 n
ia ← r.Range⟜1000 n ⋄ ib ← r.Range⟜1000 n
big ← r.Range⟜0 16777216

Median ← {s ← ∧𝕩 ⋄ m ← ≠s ⋄ 2÷˜ ((⌊(m-1)÷2)⊑s) + (⌊m÷2)⊑s}
Fmt ← {s ← •Repr 𝕩 ⋄ '-'¨⌾(('¯'=s)⊸/) s}
Bench ← {name‿inner‿elems‿F:
  F @  # warm-up (also checks the workload runs)
  t ← {𝕊: inner F •_timed @}¨ ↕samples
  •Out name ∾ (@+9) ∾ (Fmt Median t) ∾ (@+9) ∾ (Fmt ⌊´t) ∾ (@+9) ∾ (Fmt elems) ∾ (@+9) ∾ Fmt samples
}

# 1. scalar vs array: the same XOR braid, one element per call versus whole-array primitives
Bench ⟨"braid.scalar_each", 3, n, {𝕊: ⟨y, x {𝕨≠𝕩}¨ y⟩}⟩
Bench ⟨"braid.array_primitive", 50, n, {𝕊: ⟨y, x≠y⟩}⟩
Bench ⟨"braid.validated_Braid", 50, n, {𝕊: x br.Braid y}⟩
Bench ⟨"braid.roundtrip_Unbraid∘Braid", 50, n, {𝕊: br.Unbraid´ x br.Braid y}⟩
# 2. batching: 256 rows of 4096 bits, one batched call versus one call per row
Bench ⟨"batch.one_call_256x4096", 50, rows×cols, {𝕊: mx br.BatchBraid my}⟩
Bench ⟨"batch.per_row_calls_256x4096", 20, rows×cols, {𝕊: (<˘mx) br.Braid¨ <˘my}⟩
# 3. allocation: growing a Fibonacci word by repeated ∾ (fresh array per step) versus reading its length only
Bench ⟨"alloc.fib_word_24_by_append", 20, fib.Length 24, {𝕊: fib.Word 24}⟩
Bench ⟨"alloc.fresh_copy_1M_bits", 50, n, {𝕊: ¬¬x}⟩
# 4. reversible multi-strand transform on an 8 x 131072 state, forward and forward+inverse
Bench ⟨"reversible.ms_run_6ops_8x131072", 20, k×w, {𝕊: prog br.Run st}⟩
Bench ⟨"reversible.ms_roundtrip_8x131072", 10, k×w, {𝕊: inv br.Run prog br.Run st}⟩
# 5. throughput classes kept apart: float64 multiply-add (2 FLOP/element), integer add, bulk copy (memory)
Bench ⟨"flop.f64_multiply_add_1M", 50, n, {𝕊: fc + fa × fb}⟩
Bench ⟨"int.i16_add_1M", 50, n, {𝕊: ia + ib}⟩
Bench ⟨"mem.f64_reverse_copy_16M", 5, 16777216, {𝕊: ⌽big}⟩
# 6. other kernels
Bench ⟨"code.rep4_encode_262144", 20, 262144, {𝕊: arr.Rep4 262144↑x}⟩
Bench ⟨"code.rep4_decode_262144", 20, 262144, {𝕊: arr.Rep4Decode arr.Rep4 262144↑x}⟩
Bench ⟨"arrays.entropy_1M_symbols", 5, n, {𝕊: arr.Entropy sym}⟩
Bench ⟨"spiral.position_vectorised_1M", 5, n, {𝕊: sp.Position ↕n}⟩
