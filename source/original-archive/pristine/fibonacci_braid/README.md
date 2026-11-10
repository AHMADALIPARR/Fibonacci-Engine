# Fibonacci DNA braid and finite Turing machine

## Run

`node fibonacci_braid.js` (Node.js >= 18; no dependencies).

Open `braid_invariant.als` in Alloy 6 and execute `check Reversible`.
The Alloy file was authored but not run in this environment.

## Proven and tested within the JS model

- Fibonacci words: W0=A, W1=AB, W(n)=W(n-1)||W(n-2).
- DNA encoding: A -> adenine, B -> thymine (synthetic, not genome data).
- Reversible braid: (x,y)->(y,x XOR y). Inverse (a,b)->(a XOR b,a).
- Fourfold repetition code: 0 -> 0000, 1 -> 1111. Code is binary-linear and doubly even; it has no guarantee of correcting errors, and nonzero minimum distance is 4.
- General deterministic sparse-tape Turing machine runner with finite step cap, demonstrated on binary increment.

## Important limitations

- This does not simulate all atoms, the universe, quantum gravity, a Dyson sphere, or a black hole.
- 100 TFLOPS is an assumed throughput for a capacity calculation, not measured speed of this code.
- Floating-point operations, bitwise operations, and abstract TM steps are not interchangeable.
- Moore's law is about transistor scaling, not a mathematical theorem that compute throughput doubles every two years.
- The constructed doubly-even code is not evidence of a supersymmetric Adinkra or simulation hypothesis.
