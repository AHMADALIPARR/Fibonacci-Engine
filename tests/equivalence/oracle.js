// SPDX-License-Identifier: AGPL-3.0-only
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
'use strict';
// Reference oracle: evaluates the ORIGINAL fibonacci_braid.js (unmodified source text, loaded from
// source/original-archive/pristine/) and answers requests read as a JSON array on stdin.
// Non-exported top-level bindings of the original (DNA, incrementRules, getTape, xor) are reached by
// evaluating the original text in a fresh VM context with a trailing expression that returns them;
// the original text itself is not altered.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const ROOT = path.resolve(__dirname, '..', '..');
const ORIGINAL = path.join(ROOT, 'source', 'original-archive', 'pristine', 'fibonacci_braid', 'fibonacci_braid.js');
const src = fs.readFileSync(ORIGINAL, 'utf8');
const sandboxModule = { exports: {} };
const ctx = vm.createContext({ require, module: sandboxModule, exports: sandboxModule.exports, console, Uint8Array, Map, Math, JSON, Number, Array, Object, String });
const api = vm.runInContext(src + '\n;({fibonacciWords,braid,unbraid,encodeDoublyEven,decodeDoublyEven,runTM,modelWorkload,getTape,xor,DNA,incrementRules});', ctx, { filename: ORIGINAL });

const bits = (s) => Uint8Array.from([...s].map(Number));
const str = (u) => Array.from(u).join('');
function attempt(f) {
  try { return { ok: true, value: f() }; } catch (e) { return { ok: false, error: String(e && e.message || e).split('\n')[0] }; }
}

function handle(r) {
  switch (r.op) {
    case 'words': return attempt(() => api.fibonacciWords(r.count).map(str));
    case 'dna_compat': return attempt(() => [...bits(r.bits)].map((i) => api.DNA[i]).join(''));
    case 'braid': return attempt(() => api.braid(bits(r.x), bits(r.y)).map(str));
    case 'unbraid': return attempt(() => api.unbraid(bits(r.a), bits(r.b)).map(str));
    case 'xor': return attempt(() => str(api.xor(bits(r.a), bits(r.b))));
    case 'encode': return attempt(() => str(api.encodeDoublyEven([...bits(r.bits)])));
    case 'decode': return attempt(() => str(api.decodeDoublyEven(bits(r.code))));
    case 'runTM': return attempt(() => {
      const res = api.runTM({ initial: r.initial, start: r.start ?? 'scan', rules: r.rules ?? api.incrementRules, maxSteps: r.maxSteps ?? 10000 });
      return { status: res.status, state: res.state, head: res.head, steps: res.steps, tape: api.getTape(res) };
    });
    case 'modelWorkload': return attempt(() => api.modelWorkload(r.params));
    case 'incrementRules': return { ok: true, value: api.incrementRules };
    case 'main': return attempt(() => JSON.parse(execFileSync(process.execPath, [ORIGINAL], { encoding: 'utf8' })));
    default: return { ok: false, error: 'unknown op ' + r.op };
  }
}

const reqs = JSON.parse(fs.readFileSync(0, 'utf8'));
const out = { original: path.relative(ROOT, ORIGINAL), original_sha256: crypto.createHash('sha256').update(src).digest('hex'),
  node: process.version, results: reqs.map((r) => ({ id: r.id, ...handle(r) })) };
process.stdout.write(JSON.stringify(out) + '\n');
