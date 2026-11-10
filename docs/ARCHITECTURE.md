# MORPHIC HELIX: architecture, honesty boundaries, and errata

Every claim in this file points at source code, a test, or a log under `evidence/`. Run `sh scripts/verify-all.sh` to reproduce the evidence. The per-step results are in `evidence/verification/checks.tsv` and `evidence/manifests/verification.json`.

## 1. Source of truth

`source/original-archive/fibonacci_braid_engine.zip` is the archive exactly as received. `source/original-archive/pristine/` holds a byte-exact extraction of it. The SHA-256 of every entry is in `evidence/manifests/provenance.json`, and `tests/regression/test_regression.rb` re-checks those hashes. Each original code file has exactly one licence-headered copy, which differs from the pristine file only by the two prepended AGPL header lines: `fibonacci_braid.js` → `source/original-archive/fibonacci_braid/fibonacci_braid.js`, and `braid_invariant.als` → `alloy/specifications/braid_invariant.als` (the copy Alloy runs). `README.md` is documentation and exists only as the pristine file. `tests/regression/test_regression.rb` checks the header-only difference byte for byte, identical `node` output, and that no other copy of an original exists anywhere in the tree.

`tests/equivalence/oracle.js` loads the **pristine** `fibonacci_braid.js` unmodified inside a `vm` context. It does this to reach the non-exported `DNA`, `incrementRules`, `getTape`, and `xor`, and it answers JSON requests. This oracle is the reference for every port.

## 2. Components

| Directory | Contents |
|---|---|
| `ruby/application` | Ports of the original algorithms. The ported functions are `fibonacci.rb`, `dna.rb` compat encoding, `braid.rb`, `coding.rb` rep4, `turing.rb`, and `capacity.rb` `model_workload`. The extensions are the two-bit DNA code, `multistrand.rb`, `spiral.rb`, `arrays.rb`, and `physics_bounds.rb`. The GUI is `morphic_helix.rb` plus `gui/` (`panels.rb`, `domain_morphs.rb`, and `jobs.rb`, which runs tool-calling buttons off the GTK main thread). Each concept has one Ruby definition: the base-pair complement is `DNA.complement` (also used by the helix view), and the JS `main()` lane y is `Braid.rotate(x, 5)` (used by the GUI and the tests). |
| `ruby/morphic` | A minimal Morphic-style object model written here: `Morph` with bounds, submorphs, `full_draw`, `step`, and event hooks, plus widgets and `WorldMorph` hit-testing and dispatch. It is hosted in GTK 3 through ruby-gtk3 and Cairo. It is **not** Squeak or Pharo Morphic and claims no compatibility with them. |
| `ruby/protocol` | The `mh-jsonl/1` line protocol. A request has `protocol`, `id`, `op`, `input`, and `limits` (`timeout_s`, `max_steps`). A response has `id`, `op`, `ok`, `result`, `error` (`type`, `message`), and `evidence` (argv, exit status, duration, transcript SHA-256, transcript). |
| `ruby/adapters` | `process_runner.rb` handles timeouts, registers every child process group so `terminate_all` / `terminate_thread` can stop them (a stopped run raises `Cancelled`, never a partial result), kills the group when a run is interrupted, and raises `MissingTool` (`missing <tool>`). The `cbqn_adapter`, `elf_adapter`, `elf_backend`, `elf_client`, `agda_adapter`, `alloy_adapter`, and `node_oracle_adapter` files wrap the individual tools. |
| `cbqn/` | `fibonacci`, `dna`, `braid` (two-lane, batched, and multistrand), `arrays` (packing, weights, distance matrices, rep4, span, membership, closure, doubly-even, minimum distance, extended Hamming [8,4,4], windows, Fibonacci-stride permutation, frequencies, entropy), and `spiral`. `cli.bqn` is the process interface, and `arrays/bench.bqn` holds the benchmarks. |
| `elf/` | Twelf signatures for symbols, bit vectors, naturals, the Fibonacci recurrence, DNA relations, braid and inverse judgments, and Turing-machine configurations, steps, reachability, halting, and state classification. The metatheorems are checked with `%total`. For the increment machine, `classify` (total) assigns every (state, symbol) pair either `has-rule` or `is-halt`, and `has-delta` shows each `has-rule` pair has a transition; so `invalid` has no derivation for this machine: the check proves there is no invalid state, it does not detect one. |
| `alloy/specifications` | The original `braid_invariant.als` (headered copy), plus `braid_extended.als`, `dna_encoding.als`, and `turing_determinism.als`. |
| `agda/` | Self-contained proofs that use only `Agda.Builtin.*`. Every module has `{-# OPTIONS --safe --without-K #-}`, which makes `postulate` a type error. `Everything.agda` imports all of them. |
| `tests/` | `regression` (golden original output and archive hashes), `equivalence` (deterministic vectors compared JS ↔ Ruby ↔ CBQN ↔ Elf), `properties` (seeded and exhaustive Ruby properties, plus Agda and Elf **negative controls** that must be rejected), and `integration` (Elf process boundary and negative controls, Agda theorem table, process-group termination, fail-closed tools). Alloy and Agda are executed once per verification run, by `scripts/alloy-check.rb` and the agda steps of `verify-all.sh`, not again by the tests. |
| `scripts/` | `verify-all.sh`, `require-tool.sh`, `elf-check.sh`, `alloy-check.rb` (the single Alloy runner; fails unless every command meets a stated expectation), `gui-screenshots.sh`, `gui-close-test.sh`, `run_benchmarks.rb`, `bench_js.js`, `check_policy.rb`, `build_manifests.rb`. Plain shell and Ruby. The only CI configuration is `.github/workflows/pages.yml`, which publishes the existing GUI. |

### Process boundaries

* The GUI and tests call `bqn cbqn/cli.bqn <op> <args>` once per operation. Each result is compared with the Ruby engine. The CBQN console panel shows MATCH or MISMATCH per operation and keeps the command history.
* Elf crosses two boundaries. The orchestrator spawns `ruby/adapters/elf_backend.rb`, which reads `mh-jsonl/1` lines on stdin. The backend runs `twelf-server` for each request: it loads `elf/sources.cfg`, then a generated `%query` or `%solve` file. It parses the solution terms back into Ruby values. The error types are `no_derivation`, `unsupported_op`, `missing_tool`, `backend_error`, `bad_input`, and `protocol_error`.
* Agda and Alloy are run as batch checkers. Alloy receipts and solutions are in `evidence/traces/alloy/<spec>/` with outcomes in `evidence/traces/alloy/summary.json`; Agda transcripts are in `evidence/verification/logs/agda-*.log`.

### GUI threading and closing

* Buttons that run an external tool (agda, twelf-server, bqn, node) start a background job (`ruby/application/gui/jobs.rb`), one per panel at a time; a second click while one runs is refused with a visible `BUSY` line. The GTK main loop keeps drawing and keeps answering the close button while a job runs. Job threads never touch morphs: `TextMorph#content=` from another thread is queued and applied on the main thread each tick.
* Closing: the window manager's close button, Ctrl+Q, Escape (when no text field has focus; in a text field Escape only releases focus), and SIGTERM/SIGINT/SIGHUP all go through one shutdown path that cancels every job and terminates every child process group (TERM, then KILL after 2 s). Each tab has a × button; it and Ctrl+W close that panel and cancel only that panel's job; closing the last panel closes the window.
* `scripts/gui-close-test.sh` exercises every one of these paths against the real GUI under Xvfb + openbox, including closing while a real `agda Everything.agda` is running, and checks that no child process is left.

### Propositions, derivations, and computation in Elf

In Elf, a type family such as `braid X Y A B` is a **proposition** (a judgment). A term of that type is a **derivation**. The answer the backend returns is the result of logic-programming **search** for such a derivation under `%mode`. That search is the runtime computation. `%total` declarations are machine-checked metatheorems. For example, `braid-inverse` says that every braid derivation yields an unbraid derivation back to the inputs, and `encode-decode`, `fib-len` (Invariant A), and `step-det` are checked the same way. The operation `braid_inverse_derivation` returns the derivation term itself.

Some relations are not total by design, and Twelf confirms this. `xorv` (unequal lengths), `encode` (odd-length input), and "braid is an involution" are each rejected with a coverage error that lists the missing cases (`tests/properties/elf-negative/`, `evidence/verification/logs/elf-negative-*.log`). Every negative control in `verify-all.sh` must fail **with its stated failure text** (for example `Coverage error --- missing cases:`); a control that fails for any other reason is reported as UNEXPECTED. The Elf Turing machine is the binary-increment machine of the original, over the symbols 0, 1, and blank, with an explicit fuel bound. If no derivation exists within the fuel, the result is `no_derivation`.

## 3. Invariants and where they are proved

| Invariant | Agda (universal) | Bounded and runtime checks |
|---|---|---|
| A: \|W(n+2)\| = \|W(n+1)\| + \|W(n)\| | `Fibonacci/Words.agda` `invariantA`, `length-fib` (= F(n+2)) | Elf `fib-len` `%total`; Ruby property; JS ↔ Ruby ↔ CBQN ↔ Elf vectors |
| B: B⁻¹(B(x,y)) = (x,y) | `Braid/XorBraid.agda` `invariantB`, `braid-unbraid`, `braid-order3` (B³ = id), `not-involution` (B² ≠ id) | Alloy `braid_invariant.als` (exactly 8 Pos) and `braid_extended.als`; Elf `braid-inverse`, `unbraid-inverse` |
| B (Alloy translation) | `Braid/AlloyReversible.agda` `reversible`: the Alloy `Braid` signature and `BraidTransition` fact become a record over `Fin n → Bit`. `Reversible` is proved for **every** n, `check-exactly-8` is the n = 8 instance, and `model-exists` mirrors `run {}`. | Alloy result: `check Reversible` UNSAT (no counterexample) within exactly 8 Pos only |
| C: decode(encode(x)) = x | `DNA/Encoding.agda` `invariantC`, `encodeBits-sound`, `encodeBits-complete` (exactly the even-length inputs are encodable), `compat-roundtrip` | Alloy `dna_encoding.als`; Elf `encode-decode` `%total`; exhaustive Ruby round trips |
| D: XOR closure and doubly even, for the explicitly constructed code | `Coding/Repetition.agda` `xor-closed`, `doubly-even`, `min-distance-4`, `corrects-single-error`, `detects-double-error`; `windows-not-closed` gives a counterexample for the length-2 windows {00, 01, 10} of W3 = 01001 (01 ⊕ 10 = 11 is not a window) | Ruby and CBQN: the extended Hamming [8,4,4] code is closed, doubly even, and has d = 4; length-4 windows of W6 are **not** closed (counterexample recorded) |
| E: deterministic step for a functional table | `Turing/Machine.agda` `step-deterministic`, and `stepR-deterministic` for any `Functional` relation | Alloy `turing_determinism.als` (with a counterexample when functionality is dropped); Elf `step-det` `%total` |
| F: accepted trace ⇒ legal transitions from the initial configuration | `Turing/Trace.agda` `invariantF`, `runTrace-legal`; `Turing/Increment.agda` checks the concrete 1011 → 1100 run (9 configurations, 8 steps) | Ruby `legal_trace?` (a forged trace is rejected) |
| G: spiral indexing is a bijection with an inverse | `Spiral/Index.agda` `invariantG` (index ∘ position = id on ℕ), `position-injective`, `invariantG-Fin` (dependent `Fin N` indices); `Spiral/Vectors.agda` agrees with Ruby on 81 positions | Ruby `verify_bijection(40000)` and CBQN `spiral-verify` |

Three modules in `tests/properties/agda-negative/` must fail with their stated error text: a wrong step count (`9 != 11 of type Nat`), a postulate under `--safe` (`Cannot postulate`), and a false involution claim (`xorV x y != x of type Vec Bool 1`). Their outputs are kept in `evidence/verification/logs/agda-negative-*.log`.

## 4. Honesty boundaries

* **Bounded vs universal.** An Alloy UNSAT result covers only the stated scope, for example `exactly 8 Pos`, or `4 Pos` with `1..12 steps`. Only the Agda theorems quantify over all sizes. The comment in the original `.als` that says "expect no counterexample for any finite scope" is an expectation. Alloy did not prove it. The universal statement is proved in Agda as `reversible`.
* **Bitwise operations are not FLOPs.** The benchmark file reports XOR throughput as `bit-XOR/s`, float64 multiply-add as `FLOP/s`, integer add as `int-add/s`, and copy bandwidth as `GB/s`, each labelled separately. `capacity.rb`'s `budget` (O = P·t) is an **assumption** (default P = 100 TFLOP/s), not a measurement of this code.
* **Moore's law** is a configurable transistor-count scenario T(t) = T₀·2^(t/τ). It is kept separate from measured performance and is not assumed to continue.
* **Spiral indexing is not physics.** It is a lattice bijection and a data-layout tool, and the Fibonacci ring grouping only groups rings. Nothing here simulates gravitational systems or black holes. The formulas in `physics_bounds.rb` (Landauer, Bekenstein, Margolus–Levitin, Bremermann, black-hole entropy) are labelled idealised and speculative as models of computation.
* **The multistrand transform is not the braid group.** Its operators are bijections on binary states. The test `test_sigma_violates_braid_relation` shows that σ₀σ₁σ₀ ≠ σ₁σ₀σ₁ on the state (0,0,1), so these are not Artin generators.
* **Morphic** here is a minimal Morphic-style object system on GTK 3, not Squeak or Pharo.

## 5. Errata to the original README (the README itself is unchanged)

1. *"it has no guarantee of correcting errors"*: this is false. The fourfold repetition code has minimum distance 4 (`min-distance-4`). By ⌊(d−1)/2⌋ = 1 it corrects any single bit error per 4-bit block, and it detects any two errors in a block. Both facts are proved in Agda (`corrects-single-error`, `detects-double-error`) and checked exhaustively in `tests/properties/test_properties.rb`. The original JS `decodeDoublyEven` is a strict decoder: it throws on any corrupted block and never corrects. The Ruby port keeps that behaviour in `decode_rep4`, and the correcting decoder is a separate function, `correct_rep4`.
2. *"The Alloy file was authored but not run in this environment."* It has now been run with Alloy 6.2.0. `check Reversible` gives no counterexample (UNSAT) for exactly 8 Pos, and `run {}` gives an instance (SAT). See `evidence/verification/logs/alloy.log` and `evidence/traces/alloy/summary.json`. The original file carries no `expect` annotations and is not edited, so `scripts/alloy-check.rb` states its two expectations (`Reversible`: no counterexample; `run {}`: instance).
3. *"Proven and tested within the JS model"*: the JS only asserts properties on the single example in `main()`. Those are tests, not proofs. The universal proofs are the Agda modules listed in §3.

## 6. Interpretation choices (documented, not silent)

* Unequal braid lengths: the original `braid`, `unbraid`, and `xor` reject them with `assert.equal(x.length, y.length)`. All ports reject them too, and the vectors include such cases. The Ruby port also offers `braid_padded` and `unbraid_padded`, which zero-pad and record the original lengths so the operation can be inverted exactly. They are an extension and are not used in equivalence comparisons.
* The original's compat DNA code maps 0 → A and 1 → T. The extension `encode2` maps the bit pairs 00, 01, 10, 11 to A, C, G, T. Odd-length input is rejected, or zero-padded with the pad length recorded (`policy: :pad_zero`).
* Words are bounded as in the JS: count 2..24. 1 and 25 are in the vectors and are rejected everywhere.

## 7. Unverified items and limits

* Every toolchain was installed and executed: Ruby, Node, CBQN, Twelf, Agda, Alloy, Xvfb, openbox, xdotool, wmctrl, and ImageMagick. The one install failure was the Twelf 1.7.1 Linux release binary, a 32-bit ELF that failed with `No such file or directory`. It was replaced by a source build (`provenance.json`, `toolchains.twelf.not_used`).
* Elf runs are bounded for speed in the tests and GUI (words up to W10/W12, braid lanes up to 12 bits, DNA up to 24 bits, Turing runs up to 40 steps); larger inputs are compared JS ↔ Ruby ↔ CBQN only.
* Alloy results hold within the stated scopes only (see §4).
* The GUI was exercised on Xvfb with openbox only, not on a physical desktop session.
