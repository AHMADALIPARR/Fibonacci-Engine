# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# Command-line entry point used by the Ruby CBQN adapter (ruby/adapters/cbqn_adapter.rb).
#   bqn cbqn/cli.bqn <op> <args…>
# Arguments: bit vectors as 0/1 strings, matrices as comma-separated 0/1 rows, integers in decimal
# (a leading '-' is accepted). Output is line-oriented text; negative numbers are printed with '-'.
fib ← •Import "fibonacci/fibonacci.bqn"
dna ← •Import "dna/dna.bqn"
br  ← •Import "braid/braid.bqn"
arr ← •Import "arrays/arrays.bqn"
sp  ← •Import "spiral/spiral.bqn"

Split ← (¬-˜⊢×·+`»⊸>)∘≠⊔⊢
Bits ← {"argument is not a 0/1 string" ! ∧´𝕩∊"01" ⋄ 𝕩-'0'}
Rows ← {>Bits¨ ',' Split 𝕩}
Int ← {
  neg ← '-'=⊑𝕩 ⋄ d ← neg↓𝕩
  "argument is not an integer" ! (0<≠d) ∧ ∧´d∊'0'+↕10
  (1-2×neg) × 10⊸×⊸+˜´ ⌽d-'0'
}
Num ← {'-'¨⌾(('¯'=𝕩)⊸/) 𝕩}
Fmt ← {Num •Repr 𝕩}
B ← {'0'+𝕩}
R ← {1↓∾ <˘ ','∾˘ B 𝕩}
Out ← •Out
Ints ← {1↓∾ ' '⊸∾∘Fmt¨ 𝕩}
ParseOp ← {
  "operator text too short" ! 2<≠𝕩
  "bad operator separator" ! ':'=1⊑𝕩
  kind ← ⊑𝕩
  "unknown operator kind" ! ⊑kind∊"PXSs"
  ⟨kind, Int¨ ',' Split {','¨⌾(('>'=𝕩)⊸/) 𝕩} 2↓𝕩⟩
}
FmtOp ← {𝕊 k‿v:
  k ∾ ':' ∾ {k='P' ? 1↓∾ ','⊸∾∘Fmt¨ v ; k='X' ? (Fmt ⊑v) ∾ '>' ∾ Fmt 1⊑v ; Fmt ⊑v}
}

args ← •args
"usage: bqn cli.bqn <op> <args…>" ! 0<≠args
op ← ⊑args ⋄ a ← 1↓args

{
  op≡"fib-words"   ? Out∘B¨ fib.Words Int ⊑a ;
  op≡"fib-word"    ? Out B fib.Word Int ⊑a ;
  op≡"fib-lengths" ? Out Ints fib.Length¨ ↕Int ⊑a ;
  op≡"fib-index"   ? Out Fmt (Int ⊑a) fib.Index Int 1⊑a ;
  op≡"fibs"        ? Out Ints fib.Fibs Int ⊑a ;
  op≡"dna-compat"  ? Out dna.Compat Bits ⊑a ;
  op≡"dna-compat-decode" ? Out B dna.CompatDecode ⊑a ;
  op≡"dna2"        ? Out dna.Encode2 Bits ⊑a ;
  op≡"dna2-decode" ? Out B dna.Decode2 ⊑a ;
  op≡"complement"  ? Out dna.Complement ⊑a ;
  op≡"braid"       ? Out∘B¨ (Bits ⊑a) br.Braid Bits 1⊑a ;
  op≡"unbraid"     ? Out∘B¨ (Bits ⊑a) br.Unbraid Bits 1⊑a ;
  op≡"batch-braid"   ? Out∘R¨ (Rows ⊑a) br.BatchBraid Rows 1⊑a ;
  op≡"batch-unbraid" ? Out∘R¨ (Rows ⊑a) br.BatchUnbraid Rows 1⊑a ;
  op≡"pack"        ? l‿by ← arr.Pack Bits ⊑a ⋄ Out Ints l∾by ;
  op≡"unpack"      ? Out B arr.Unpack ⟨Int ⊑a, Int¨ 1↓a⟩ ;
  op≡"weight"      ? Out Fmt arr.Weight Bits ⊑a ;
  op≡"distmat"     ? Out∘Ints˘ arr.DistMatrix Rows ⊑a ;
  op≡"rep4"        ? Out B arr.Rep4 Bits ⊑a ;
  op≡"rep4-decode" ? Out B arr.Rep4Decode Bits ⊑a ;
  op≡"rep4-correct" ? Out B arr.Rep4Correct Bits ⊑a ;
  op≡"span"        ? Out R arr.Span Rows ⊑a ;
  op≡"ext-hamming" ? Out R arr.extHamming ;
  op≡"member"      ? Out Fmt (Rows ⊑a) arr.Member Bits 1⊑a ;
  op≡"closure"     ? Out Ints arr.Closure Rows ⊑a ;
  op≡"doubly-even" ? Out Ints arr.DoublyEven Rows ⊑a ;
  op≡"min-distance" ? Out Fmt arr.MinDistance Rows ⊑a ;
  op≡"windows"     ? Out 1↓∾ ','⊸∾∘B¨ (Int ⊑a) arr.Windows Bits 1⊑a ;
  op≡"fib-perm"    ? Out Ints arr.FibPerm Int ⊑a ;
  op≡"fib-permute" ? Out B arr.FibPermute Bits ⊑a ;
  op≡"fib-unpermute" ? Out B arr.FibUnpermute Bits ⊑a ;
  op≡"frequencies" ? s‿c ← arr.Frequencies ⊑a ⋄ Out s ⋄ Out Ints c ;
  op≡"entropy"     ? Out Fmt arr.Entropy ⊑a ;
  op≡"spiral"      ? Out 1↓∾ {' '∾(Fmt ⊑𝕩)∾','∾Fmt 1⊑𝕩}¨ <˘ sp.Position ↕Int ⊑a ;
  op≡"spiral-index" ? Out Fmt sp.Index Int¨ a ;
  op≡"spiral-verify" ? Out Fmt sp.VerifyBijection Int ⊑a ;
  op≡"spiral3"     ? Out 1↓∾ {' '∾1↓∾','⊸∾∘Fmt¨ 𝕩}¨ <˘ (Int ⊑a) sp.Position3 ↕Int 1⊑a ;
  op≡"spiral-ring" ? Out∘Ints˘ sp.RingCoord ↕Int ⊑a ;
  op≡"inspect"     ? m ← Rows ⊑a ⋄ Out Ints ≢m ⋄ Out Fmt =m ⋄ Out Ints +´˘m ;
  op≡"ms-run"      ? prog ← ParseOp¨ 1↓a ⋄ Out∘br.Serialize¨ prog br.History Rows ⊑a ;
  op≡"ms-inverse"  ? Out 1↓∾ ' '⊸∾∘FmtOp¨ br.InverseProgram ParseOp¨ a ;
  op≡"ms-period"   ? prog ← ParseOp¨ 2↓a ⋄ Out Fmt ((Int ⊑a)‿prog) br.Period Rows 1⊑a ;
  "unknown op" ! 0
}
