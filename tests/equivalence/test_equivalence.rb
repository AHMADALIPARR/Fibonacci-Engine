# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Cross-language equivalence on the deterministic vectors in vectors.json.
#   JS oracle (original fibonacci_braid.js)  vs  Ruby port  vs  CBQN kernels  vs  Elf (Twelf) relations
# A machine-readable record of every comparison is written to evidence/traces/equivalence.json.
require 'minitest/autorun'
require 'json'
root = File.expand_path('../..', __dir__)
%w[fibonacci dna braid multistrand coding turing spiral arrays capacity].each { |f| require File.join(root, 'ruby', 'application', f) }
require File.join(root, 'ruby', 'adapters', 'cbqn_adapter')
require File.join(root, 'ruby', 'adapters', 'elf_adapter')
require File.join(root, 'ruby', 'adapters', 'node_oracle_adapter')

module EquivalenceRecord
  ROOT = File.expand_path('../..', __dir__)
  @rows = []
  class << self
    attr_reader :rows

    def add(suite, kase, langs, equal, detail = nil)
      @rows << { suite: suite, case: kase, languages: langs, equal: equal, detail: detail }
    end
  end
  Minitest.after_run do
    path = File.join(ROOT, 'evidence', 'traces', 'equivalence.json')
    File.write(path, JSON.pretty_generate({ comparisons: @rows.length, mismatches: @rows.count { |r| !r[:equal] }, rows: @rows }) + "\n")
  end
end

class EquivalenceTest < Minitest::Test
  include MorphicHelix
  ROOT = EquivalenceRecord::ROOT
  V = JSON.parse(File.read(File.join(__dir__, 'vectors.json')))

  def self.oracle
    @oracle ||= begin
      reqs = []
      V['words'].each { |c| reqs << { id: "w#{c}", op: 'words', count: c } }
      V['braid'].each_with_index { |b, i| reqs << { id: "b#{i}", op: 'braid', x: b['x'], y: b['y'] } << { id: "u#{i}", op: 'unbraid', a: b['x'], b: b['y'] } }
      V['rep4_encode'].each_with_index { |b, i| reqs << { id: "e#{i}", op: 'encode', bits: b } }
      V['rep4_decode'].each_with_index { |c, i| reqs << { id: "d#{i}", op: 'decode', code: c } }
      V['tm'].each_with_index { |t, i| reqs << { id: "t#{i}", op: 'runTM', initial: t['initial'], maxSteps: t['maxSteps'] } }
      V['workload'].each_with_index { |p, i| reqs << { id: "m#{i}", op: 'modelWorkload', params: p } }
      reqs << { id: 'main', op: 'main' }
      out = NodeOracle.new.call(reqs)
      out['results'].to_h { |r| [r['id'], r] }.merge('_meta' => out.reject { |k, _| k == 'results' })
    end
  end

  def oracle = self.class.oracle
  def cbqn = (@cbqn ||= CBQNAdapter.new)
  def elf = (@elf ||= ElfAdapter.new(timeout_s: 60))
  def s01(v) = v.join
  def b(s) = Fibonacci.from_s01(s)

  def ruby_try
    { ok: true, value: yield }
  rescue StandardError => e
    { ok: false, error: e.message }
  end

  def check(suite, kase, langs, expected, actual, detail = nil)
    eq = expected == actual
    EquivalenceRecord.add(suite, kase, langs, eq, eq ? { expected: expected } : (detail || { expected: expected, actual: actual }))
    assert_equal expected, actual, "#{suite} #{kase} #{langs.join(' vs ')}"
  end

  def test_oracle_uses_pristine_original
    meta = oracle['_meta']
    want = Digest::SHA256.file(File.join(ROOT, 'source/original-archive/pristine/fibonacci_braid/fibonacci_braid.js')).hexdigest
    check('oracle', 'original sha256', %w[js], want, meta['original_sha256'])
  end

  def test_words_js_ruby_cbqn_elf
    V['words'].each do |c|
      js = oracle["w#{c}"]
      rb = ruby_try { Fibonacci.words(c).map { |w| s01(w) } }
      check('words', c, %w[js ruby], js['ok'], rb[:ok])
      next unless js['ok']

      check('words', c, %w[js ruby], js['value'], rb[:value])
      bq = cbqn.call('fib-words', c)
      check('words', c, %w[js cbqn], js['value'], bq)
      next unless c <= 11

      ev = elf.fib_word(c - 1)
      check('words', c, %w[js elf], js['value'].last, s01(ev[:result]))
    end
    # count 25 is outside the JS bound: CBQN must reject it with its bound message (JS rejection is checked above).
    bad = begin; cbqn.call('fib-words', 25); nil; rescue BackendError => e; e.message; end
    check('words', 25, %w[js cbqn], true, bad.to_s.include?('count must be'))
  end

  def test_braid_unbraid
    V['braid'].each_with_index do |v, i|
      js_b = oracle["b#{i}"]
      js_u = oracle["u#{i}"]
      rb_b = ruby_try { Braid.braid(b(v['x']), b(v['y'])).map { |w| s01(w) } }
      rb_u = ruby_try { Braid.unbraid(b(v['x']), b(v['y'])).map { |w| s01(w) } }
      check('braid', i, %w[js ruby], [js_b['ok'], js_b['value']], [rb_b[:ok], rb_b[:value]])
      check('unbraid', i, %w[js ruby], [js_u['ok'], js_u['value']], [rb_u[:ok], rb_u[:value]])
      if js_b['ok']
        check('braid', i, %w[js cbqn], js_b['value'], cbqn.call('braid', v['x'], v['y']))
        check('unbraid', i, %w[js cbqn], js_u['value'], cbqn.call('unbraid', v['x'], v['y']))
        if v['x'].length <= 12
          check('braid', i, %w[js elf], js_b['value'], elf.braid(b(v['x']), b(v['y']))[:result].map { |w| s01(w) })
          check('unbraid', i, %w[js elf], js_u['value'], elf.unbraid(b(v['x']), b(v['y']))[:result].map { |w| s01(w) })
        end
      else
        r = elf.braid(b(v['x']), b(v['y']))
        check('braid', i, %w[js elf], false, r[:ok])
        err = begin; cbqn.call('braid', v['x'], v['y']); nil; rescue BackendError => e; e.message; end
        check('braid', i, %w[js cbqn], true, err.to_s.include?('length mismatch'))
      end
    end
  end

  def test_rep4
    V['rep4_encode'].each_with_index do |bits, i|
      js = oracle["e#{i}"]
      check('rep4_encode', i, %w[js ruby], js['value'], s01(Coding.encode_rep4(b(bits))))
      check('rep4_encode', i, %w[js cbqn], js['value'], cbqn.call('rep4', bits).first)
    end
    V['rep4_decode'].each_with_index do |code, i|
      js = oracle["d#{i}"]
      rb = ruby_try { s01(Coding.decode_rep4(b(code))) }
      check('rep4_decode', i, %w[js ruby], [js['ok'], js['value']], [rb[:ok], rb[:value]])
      bq = begin; [true, cbqn.call('rep4-decode', code).first]; rescue BackendError; [false, nil]; end
      check('rep4_decode', i, %w[js cbqn], [js['ok'], js['value']], bq)
    end
  end

  def test_turing_machine
    V['tm'].each_with_index do |t, i|
      js = oracle["t#{i}"]['value']
      r = Turing.run(initial: t['initial'], start: 'scan', rules: Turing::INCREMENT_RULES, max_steps: t['maxSteps'])
      rb = { 'status' => r[:status], 'state' => r[:state], 'head' => r[:head], 'steps' => r[:steps], 'tape' => Turing.get_tape(r[:tape]) }
      check('tm', i, %w[js ruby], js, rb)
      next unless t['initial'].match?(/\A[01]*\z/) && t['maxSteps'] <= 40

      e = elf.tm_increment(t['initial'], t['maxSteps'])
      if js['status'] == 'HALT'
        check('tm', i, %w[js elf], [js['steps'], js['tape']], [e[:result]['steps'], e[:result]['output']])
      else
        check('tm', i, %w[js elf], false, e[:ok])
      end
    end
  end

  def test_model_workload
    V['workload'].each_with_index do |p, i|
      js = oracle["m#{i}"]['value']
      kw = { target_tflops: p.fetch('targetTFLOPS', 100), seconds: p.fetch('seconds', 1), flops_per_step: p.fetch('flopsPerStep', 1000) }
      rb = Capacity.model_workload(**kw)
      check('workload', i, %w[js ruby], [js['operations'].to_f, js['hypotheticalSteps'].to_f, js['note']],
            [rb[:operations].to_f, rb[:hypotheticalSteps].to_f, rb[:note]])
    end
  end

  def test_main_report
    js = oracle['main']['value']
    words = Fibonacci.words(7)
    word = words.last
    y = Braid.rotate(word, 5)
    a, bb = Braid.braid(word, y)
    code = Coding.encode_rep4(a)
    tm = Turing.run(initial: '1011', start: 'scan', rules: Turing::INCREMENT_RULES)
    rb = { 'fibonacciLength' => word.length, 'dna' => DNA.compat_encode(word), 'codeLength' => code.length,
           'turingMachine' => { 'status' => tm[:status], 'steps' => tm[:steps], 'output' => Turing.get_tape(tm[:tape]) },
           'codeXorClosed' => Braid.xor(code, Coding.encode_rep4(bb)) == Coding.encode_rep4(Braid.xor(a, bb)),
           'doublyEven' => (code.sum % 4).zero?, 'braidReversible' => Braid.unbraid(a, bb) == [word, y] }
    check('main', 'report', %w[js ruby], js.slice(*rb.keys), rb)
  end

  def test_dna2_ruby_cbqn_elf
    V['dna2'].each_with_index do |bits, i|
      rb = ruby_try { DNA.encode2(b(bits))[:bases] }
      if rb[:ok]
        check('dna2', i, %w[ruby cbqn], rb[:value], cbqn.call('dna2', bits).first.to_s)
        check('dna2-decode', i, %w[ruby cbqn], bits, cbqn.call('dna2-decode', rb[:value]).first.to_s)
        check('dna2', i, %w[ruby elf], rb[:value], elf.dna_encode(b(bits))[:result]) if bits.length <= 24
        check('dna2-decode', i, %w[ruby elf], b(bits), elf.dna_decode(rb[:value])[:result]) if bits.length <= 24
      else
        check('dna2', i, %w[ruby elf], false, elf.dna_encode(b(bits))[:ok])
        err = begin; cbqn.call('dna2', bits); nil; rescue BackendError => e; e.message; end
        check('dna2', i, %w[ruby cbqn], true, err.to_s.include?('odd-length'))
      end
    end
  end

  def test_pack_distmat_entropy_fibperm
    V['pack'].each_with_index do |bits, i|
      p = Fibonacci.pack(b(bits))
      check('pack', i, %w[ruby cbqn], ([p[:length]] + p[:bytes]).join(' '), cbqn.call('pack', bits).first)
      check('unpack', i, %w[ruby cbqn], bits, cbqn.call('unpack', p[:length], *p[:bytes]).first.to_s)
    end
    V['matrices'].each_with_index do |rows, i|
      m = rows.map { |r| b(r) }
      check('distmat', i, %w[ruby cbqn], Coding.distance_matrix(m).map { |r| r.join(' ') }, cbqn.call('distmat', rows.join(',')))
    end
    V['entropy'].each_with_index do |s, i|
      got = Float(cbqn.call('entropy', s).first.tr('¯', '-'))
      check('entropy', i, %w[ruby cbqn], Arrays.entropy(s.chars), got)
      syms, counts = Arrays.frequencies(s.chars)
      check('frequencies', i, %w[ruby cbqn], [syms.join, counts.join(' ')], cbqn.call('frequencies', s))
    end
    V['fibperm'].each do |n|
      check('fibperm', n, %w[ruby cbqn], Arrays.fib_perm(n).join(' '), cbqn.call('fib-perm', n).first)
    end
  end

  def test_spiral_ruby_cbqn
    V['spiral_n'].each do |n|
      check('spiral', n, %w[ruby cbqn], (0...n).map { |k| Spiral.position(k).join(',') }.join(' '), cbqn.call('spiral', n).first)
      check('spiral-verify', n, %w[ruby cbqn], Spiral.verify_bijection(n)[:ok] ? '1' : '0', cbqn.call('spiral-verify', n).first)
    end
    [[3, 0], [-2, 5], [7, -7], [-4, -4], [0, -1]].each do |x, y|
      check('spiral-index', "#{x},#{y}", %w[ruby cbqn], Spiral.index(x, y).to_s, cbqn.call('spiral-index', x, y).first)
    end
    check('spiral3', 'side3', %w[ruby cbqn], (0...27).map { |i| Spiral.position3(i, 3).join(',') }.join(' '), cbqn.call('spiral3', 3, 27).first)
  end

  def test_multistrand_ruby_cbqn
    V['multistrand'].each_with_index do |c, i|
      st = c['state'].map { |r| b(r) }
      prog = c['program'].map { |t| Multistrand.parse_op(t) }
      hist = Multistrand.run(prog, st)[:history].map { |h| Multistrand.serialize(h[:state]) }
      check('ms-run', i, %w[ruby cbqn], hist, cbqn.call('ms-run', c['state'].join(','), *c['program']))
      check('ms-inverse', i, %w[ruby cbqn], Multistrand.inverse_program(prog).map(&:to_s).join(' '), cbqn.call('ms-inverse', *c['program']).first)
      per = Multistrand.period(prog, st, limit: 5000)[:period]
      check('ms-period', i, %w[ruby cbqn], per.to_s, cbqn.call('ms-period', 5000, c['state'].join(','), *c['program']).first)
      back = Multistrand.run(Multistrand.inverse_program(prog), Multistrand.run(prog, st)[:state])[:state]
      check('ms-roundtrip', i, %w[ruby], st, back)
    end
  end

  def test_codes_ruby_cbqn
    V['codes'].each_with_index do |gen, i|
      g = gen.map { |r| b(r) }
      span = Coding.span(g)
      check('span', i, %w[ruby cbqn], span.map(&:join).join(','), cbqn.call('span', gen.join(',')).first)
      cl = Coding.xor_closure(span)
      want = cl[:closed] ? '1' : "0 #{cl[:i]} #{cl[:j]}"
      check('closure', i, %w[ruby cbqn], want, cbqn.call('closure', span.map(&:join).join(',')).first)
      de = Coding.doubly_even(span)
      want = de[:doubly_even] ? '1' : "0 #{de[:i]} #{de[:weight]}"
      check('doubly-even', i, %w[ruby cbqn], want, cbqn.call('doubly-even', span.map(&:join).join(',')).first)
    end
    eh = Coding.span(Coding::EXT_HAMMING_8_4_G)
    check('ext-hamming', 'span', %w[ruby cbqn], eh.map(&:join).join(','), cbqn.call('ext-hamming').first.then { |g| cbqn.call('span', g).first })
    check('ext-hamming', 'min-distance', %w[ruby cbqn], Coding.min_distance(eh).to_s, cbqn.call('min-distance', eh.map(&:join).join(',')).first)
    win = Coding.fibonacci_windows(6, 4)
    check('fib-windows', 'W6 w=4', %w[ruby cbqn], win.map(&:join).join(','), cbqn.call('windows', 4, Fibonacci.word(6).join).first)
    cl = Coding.xor_closure(win)
    want = cl[:closed] ? '1' : "0 #{cl[:i]} #{cl[:j]}"
    check('fib-windows', 'closure counterexample', %w[ruby cbqn], want, cbqn.call('closure', win.map(&:join).join(',')).first)
  end
end
