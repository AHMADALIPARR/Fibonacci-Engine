// SPDX-License-Identifier: AGPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
//
// Node benchmarks of the ORIGINAL (pristine, unmodified) fibonacci_braid.js functions.
// Usage: node scripts/bench_js.js [samples]  ->  name<TAB>median_s<TAB>min_s<TAB>elements<TAB>samples
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ORIGINAL = path.resolve(__dirname, '..', 'source', 'original-archive', 'pristine', 'fibonacci_braid', 'fibonacci_braid.js');
const mod = { exports: {} };
const ctx = vm.createContext({ require, module: mod, exports: mod.exports, console, Uint8Array, Map, Math, JSON, Number, Array, Object, String });
const api = vm.runInContext(fs.readFileSync(ORIGINAL, 'utf8') + '\n;({fibonacciWords,braid,unbraid,encodeDoublyEven,decodeDoublyEven,runTM,incrementRules});', ctx, { filename: ORIGINAL });
const samples = Number(process.argv[2] || 7);
let seed = 20261110;
const rnd = () => { seed = (seed * 1103515245 + 12345) % 2147483648; return (seed >> 16) & 1; };
const n = 1048576;
const x = new Uint8Array(n).map(rnd);
const y = new Uint8Array(n).map(rnd);
function bench(name, inner, elems, f) {
  f();
  const t = [];
  for (let s = 0; s < samples; s++) {
    const t0 = process.hrtime.bigint();
    for (let i = 0; i < inner; i++) f();
    t.push(Number(process.hrtime.bigint() - t0) / 1e9 / inner);
  }
  t.sort((a, b) => a - b);
  const m = t.length % 2 ? t[(t.length - 1) / 2] : (t[t.length / 2 - 1] + t[t.length / 2]) / 2;
  console.log([name, m, t[0], elems, samples].join('\t'));
}
bench('js.braid_1M', 20, n, () => api.braid(x, y));
bench('js.roundtrip_1M', 20, n, () => { const [a, b] = api.braid(x, y); return api.unbraid(a, b); });
bench('js.rep4_encode_262144', 10, 262144, () => api.encodeDoublyEven(Array.from(x.subarray(0, 262144))));
bench('js.fibonacci_words_24', 20, 121393, () => api.fibonacciWords(24));
bench('js.runTM_1011', 2000, 8, () => api.runTM({ initial: '1011', start: 'scan', rules: api.incrementRules }));
