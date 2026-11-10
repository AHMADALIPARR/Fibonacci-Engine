# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'json'
require_relative 'domain_morphs'
require_relative 'jobs'
require_relative '../fibonacci'
require_relative '../dna'
require_relative '../braid'
require_relative '../multistrand'
require_relative '../coding'
require_relative '../turing'
require_relative '../spiral'
require_relative '../arrays'
require_relative '../capacity'
require_relative '../physics_bounds'
require_relative '../../adapters/cbqn_adapter'
require_relative '../../adapters/elf_client'
require_relative '../../adapters/elf_adapter'
require_relative '../../adapters/agda_adapter'
require_relative '../../adapters/node_oracle_adapter'

module MorphicHelix
  module GUI
    include Morphic
    P = Morphic::Palette

    # Shared application state (one Fibonacci word drives the helix, braid and CBQN panels).
    class State
      attr_accessor :depth, :encoding, :listeners

      def initialize
        @depth = 6
        @encoding = 'compat'
        @listeners = []
      end

      def word = Fibonacci.word(@depth)

      def dna
        bits = word
        @encoding == 'compat' ? DNA.compat_encode(bits) : DNA.encode2(bits, policy: :pad_zero)[:bases]
      end

      def changed! = @listeners.each(&:call)
    end

    # Runs an action that calls external tools as a background job of this panel (see gui/jobs.rb).
    def self.job(panel, text_morph, label, &work) = Jobs.start(panel.name, text_morph, label, &work)

    class Panel < Morphic::Morph
      def initialize(world_w, world_h, name)
        super(x: 0, y: 44, width: world_w, height: world_h - 44, color: P::BG, name: name)
      end

      def label(str, x, y, size: 13, color: P::TEXT, bold: false)
        add(Morphic::StringMorph.new(str, x: @x + x, y: @y + y, width: 900, size: size, color: color, bold: bold))
      end

      def button(lbl, x, y, w, name, &blk) = add(Morphic::ButtonMorph.new(lbl, blk, x: @x + x, y: @y + y, width: w, name: name))
      def textbox(x, y, w, h, name, size: 12) = add(Morphic::TextMorph.new([], x: @x + x, y: @y + y, width: w, height: h, name: name, size: size))
      def ok(b) = b ? ['✓', P::OK] : ['✗', P::BAD]
    end

    class FibonacciPanel < Panel
      def initialize(state, ww, wh)
        super(ww, wh, 'panel-fibonacci')
        @state = state
        label('Fibonacci generator   W0 = A, W1 = AB, W(n+2) = W(n+1) || W(n)', 20, 12, size: 16, bold: true)
        label('depth n', 20, 52, color: P::DIM)
        @slider = add(Morphic::SliderMorph.new(min: 0, max: 20, value: state.depth, x: @x + 100, y: @y + 50, width: 400, name: 'fib-depth',
                                               on_change: ->(v) { @state.depth = v; @state.changed! }))
        label('DNA encoding', 540, 52, color: P::DIM)
        add(Morphic::ChoiceMorph.new(['compat', 'two-bit'], x: @x + 650, y: @y + 48, width: 160, name: 'fib-encoding',
                                     on_change: ->(v) { @state.encoding = v; @state.changed! }))
        @preview = textbox(20, 90, 820, 300, 'fib-preview')
        @recur = textbox(860, 90, 520, 300, 'fib-recurrence')
        button('Verify length & word across JS / Ruby / CBQN / Elf', 20, 405, 420, 'btn-fib-verify') { verify }
        @verify = textbox(20, 440, 1360, 400, 'fib-verify-out')
        state.listeners << -> { refresh }
        refresh
      end

      def refresh
        n = @state.depth
        w = @state.word
        ab = w.map { |b| b.zero? ? 'A' : 'B' }.join
        syms, counts = Arrays.frequencies(ab.chars)
        wrap = ->(s) { s.scan(/.{1,96}/) }
        lines = ["W#{n}  (length #{w.length})", ''] + wrap.call(ab).first(4) + ['', 'bits:'] + wrap.call(w.join).first(3) +
                ['', "DNA (#{@state.encoding}):"] + wrap.call(@state.dna).first(3) +
                ['', "symbol frequencies: #{syms.zip(counts).map { |s, c| "#{s}=#{c}" }.join('  ')}",
                 "Shannon entropy: #{Arrays.entropy(ab.chars)} bits/symbol"]
        @preview.content = lines
        rec = ['k   |W_k|  |W_k-1|+|W_k-2|  F(k+2)  check']
        (0..n).each do |k|
          lk = Fibonacci.length(k)
          sum = k >= 2 ? Fibonacci.length(k - 1) + Fibonacci.length(k - 2) : nil
          good = (sum.nil? || sum == lk) && lk == Fibonacci.fib(k + 2) && lk == Fibonacci.word(k).length
          rec << [format('%-3d %-6d %-16s %-7d %s', k, lk, sum || '-', Fibonacci.fib(k + 2), good ? 'ok' : 'FAIL'), good ? P::TEXT : P::BAD]
        end
        @recur.content = rec
      end

      def verify
        GUI.job(self, @verify, 'verify Fibonacci word (JS / Ruby / CBQN / Elf)') do
          n = @state.depth
          ruby = @state.word.join
          lines = ["Depth n=#{n}. Ruby: length #{ruby.length}"]
          if n + 1 >= 2 && n + 1 <= 24
            js = NodeOracle.new.call([{ id: 1, op: 'words', count: n + 1 }])
            jw = js['results'][0]['value'].last
            lines << ["JS oracle (original fibonacci_braid.js, sha256 #{js['original_sha256'][0, 12]}…): length #{jw.length} #{jw == ruby ? 'EXACT MATCH' : 'MISMATCH'}", jw == ruby ? P::OK : P::BAD]
          else
            lines << 'JS oracle: depth outside the original JS bound 2 <= count <= 24 (not run)'
          end
          bq = CBQNAdapter.new.call('fib-word', n).first
          lines << ["CBQN (bqn cbqn/cli.bqn fib-word #{n}): length #{bq.length} #{bq == ruby ? 'EXACT MATCH' : 'MISMATCH'}", bq == ruby ? P::OK : P::BAD]
          if n <= 12
            client = ElfClient.new
            r = client.call('fib_word', { 'n' => n }, { 'timeout_s' => 60 })
            client.close
            ew = r['ok'] ? r['result']['value'].join : nil
            lines << ["Elf (twelf-server, %query fibword): #{r['ok'] ? "length #{ew.length} #{ew == ruby ? 'EXACT MATCH' : 'MISMATCH'}" : r['error']}", ew == ruby ? P::OK : P::BAD]
          else
            lines << 'Elf: not run for n > 12 in the GUI (LF term printing grows with |W_n|); see tests/equivalence for the recorded runs.'
          end
          @verify.content = lines
        end
      end
    end

    class HelixPanel < Panel
      def initialize(state, ww, wh)
        super(ww, wh, 'panel-helix')
        @state = state
        label('DNA helix viewer  (drag = rotate, wheel = zoom, click = select base pair)', 20, 12, size: 16, bold: true)
        @helix = add(Morphic::HelixMorph.new(x: @x + 20, y: @y + 44, width: 1360, height: 330, name: 'helix'))
        button('zoom +', 20, 384, 90, 'btn-helix-zoom-in') { @helix.zoom = [@helix.zoom * 1.2, 3.0].min }
        button('zoom −', 120, 384, 90, 'btn-helix-zoom-out') { @helix.zoom = [@helix.zoom / 1.2, 0.4].max }
        button('auto-rotate', 220, 384, 120, 'btn-helix-rotate') { @helix.auto_rotate = !@helix.auto_rotate }
        button('◀', 350, 384, 40, 'btn-helix-left') { @helix.angle -= 0.4 }
        button('▶', 400, 384, 40, 'btn-helix-right') { @helix.angle += 0.4 }
        add(Morphic::ChoiceMorph.new(['both', 'strand 1', 'strand 2'], x: @x + 460, y: @y + 384, width: 140, name: 'helix-strands',
                                     on_change: ->(v) { @helix.strand_mode = v }))
        button('pair −', 620, 384, 80, 'btn-helix-prev') { @helix.highlight = [(@helix.highlight || 1) - 1, 0].max }
        button('pair +', 710, 384, 80, 'btn-helix-next') { @helix.highlight = [(@helix.highlight || -1) + 1, @helix.sequence.length - 1].min }
        label('Braid B(x,y) = (y, x XOR y) on lane x = W_n, lane y = W_n rotated by 5 (as in the JS main())', 20, 426, size: 13, color: P::DIM)
        button('Forward braid', 20, 452, 140, 'btn-braid-forward') { @stage = 1; show_braid }
        button('Inverse braid', 170, 452, 140, 'btn-braid-inverse') { @stage = 2; show_braid }
        @lanes = add(Morphic::BitRowsMorph.new(x: @x + 20, y: @y + 488, width: 1360, height: 140, name: 'braid-lanes'))
        @braid_text = textbox(20, 636, 1360, 200, 'braid-out')
        @stage = 0
        state.listeners << -> { refresh }
        refresh
      end

      def refresh
        @helix.sequence = @state.dna
        @helix.highlight = nil if @helix.highlight && @helix.highlight >= @helix.sequence.length
        show_braid
      end

      def show_braid
        x = @state.word
        y = Braid.rotate(x, 5)
        a, b = Braid.braid(x, y)
        rx, ry = Braid.unbraid(a, b)
        rows = [['x', x, P::ACCENT], ['y', y, P::ACCENT]]
        rows += [['a = y', a, P::WARN], ['b = x XOR y', b, P::WARN]] if @stage >= 1
        rows += [['B⁻¹ → x', rx, P::OK], ['B⁻¹ → y', ry, P::OK]] if @stage >= 2
        @lanes.rows = rows
        txt = ["lane length #{x.length}; stage: #{%w[input forward inverse][@stage]}"]
        txt << "a = #{a.join}" << "b = #{b.join}" if @stage >= 1
        if @stage >= 2
          txt << "restored x == x: #{rx == x}   restored y == y: #{ry == y}"
          c1 = Coding.encode_rep4(a)
          txt << "rep4(a): length #{c1.length}, weight #{c1.sum} (mod 4 = #{c1.sum % 4}); strict decode == a: #{Coding.decode_rep4(c1) == a}"
        end
        @braid_text.content = txt
      end
    end

    class CBQNPanel < Panel
      def initialize(state, ww, wh)
        super(ww, wh, 'panel-cbqn')
        @state = state
        @cbqn = CBQNAdapter.new
        label('CBQN array console  (every row runs `bqn cbqn/cli.bqn …` and is compared with the Ruby engine)', 20, 12, size: 16, bold: true)
        @ops = %w[braid weight distmat inspect pack rep4 closure doubly-even fib-permute entropy spiral ms-run ms-period]
        @list = add(Morphic::ListMorph.new(@ops, x: @x + 20, y: @y + 48, width: 220, height: 300, name: 'cbqn-ops',
                                           on_select: ->(_i, _v) { nil }))
        @list.selected = 0
        label('input bits (default: current W_n)', 260, 48, color: P::DIM)
        @input = add(Morphic::TextFieldMorph.new('', allowed: /\A[01]\z/, x: @x + 260, y: @y + 72, width: 1120, name: 'cbqn-input'))
        button('Run in CBQN', 260, 108, 160, 'btn-cbqn-run') { run }
        button('Run all ops', 430, 108, 160, 'btn-cbqn-all') { run_all }
        @out = textbox(260, 144, 1120, 380, 'cbqn-out')
        label('vector-operation history (most recent last)', 20, 536, color: P::DIM)
        @hist = textbox(20, 560, 1360, 280, 'cbqn-history', size: 11)
      end

      def bits = (@input.string.empty? ? @state.word : Fibonacci.from_s01(@input.string))
      def rows = (bits.each_slice(8).select { |r| r.length == 8 }.first(6).then { |r| r.empty? ? [bits] : r })

      def compute(op)
        b = bits
        y = Braid.rotate(b, 5)
        s = ->(v) { v.join }
        case op
        when 'braid' then [[s[b], s[y]], Braid.braid(b, y).map(&:join)]
        when 'weight' then [[s[b]], [Coding.weight(b).to_s]]
        when 'distmat' then [[rows.map(&:join).join(',')], Coding.distance_matrix(rows).map { |r| r.join(' ') }]
        when 'inspect' then [[rows.map(&:join).join(',')], ["#{rows.length} #{rows.first.length}", '2', rows.map(&:sum).join(' ')]]
        when 'pack' then [[s[b]], [Fibonacci.pack(b).then { |p| ([p[:length]] + p[:bytes]).join(' ') }]]
        when 'rep4' then [[s[b]], [Coding.encode_rep4(b).join]]
        when 'closure' then
          c = Coding.span(Coding::EXT_HAMMING_8_4_G)
          [[c.map(&:join).join(',')], [Coding.xor_closure(c)[:closed] ? '1' : '0']]
        when 'doubly-even' then
          c = Coding.span(Coding::EXT_HAMMING_8_4_G)
          [[c.map(&:join).join(',')], [Coding.doubly_even(c)[:doubly_even] ? '1' : '0']]
        when 'fib-permute' then [[s[b]], [Arrays.fib_permute(b).join]]
        when 'entropy' then [[@state.dna], [Arrays.entropy(@state.dna.chars)]]
        when 'spiral' then [[b.length.to_s], [(0...b.length).map { |k| Spiral.position(k).join(',') }.join(' ')]]
        when 'ms-run', 'ms-period'
          st = [b.first(8), y.first(8), Braid.xor(b.first(8), y.first(8))]
          prog = %w[S:0 X:1>2 P:2,0,1].map { |t| Multistrand.parse_op(t) }
          if op == 'ms-run'
            [[st.map(&:join).join(','), 'S:0', 'X:1>2', 'P:2,0,1'], Multistrand.run(prog, st)[:history].map { |h| Multistrand.serialize(h[:state]) }]
          else
            [['1000', st.map(&:join).join(','), 'S:0', 'X:1>2', 'P:2,0,1'], [Multistrand.period(prog, st)[:period].to_s]]
          end
        end
      end

      def compare(op, got, want)
        return got.first.tr('¯', '-').to_f == want.first if op == 'entropy'

        got == want.map(&:to_s)
      end

      def run_one(op)
        args, want = compute(op)
        got = @cbqn.call(op, *args)
        [op, args, got, want, compare(op, got, want)]
      end

      def run
        GUI.job(self, @out, 'CBQN run') do
          op = @ops[@list.selected || 0]
          op, args, got, want, same = run_one(op)
          shape = @cbqn.call('inspect', rows.map(&:join).join(','))
          @out.content = ["op: #{op}", "args: #{args.join(' ')[0, 150]}", '', 'CBQN output:'] + got.first(8).map { |l| "  #{l[0, 150]}" } +
                         ['', 'Ruby reference:'] + want.first(8).map { |l| "  #{l.to_s[0, 150]}" } + ['',
                         [same ? 'EXACT MATCH (CBQN == Ruby)' : 'MISMATCH', same ? P::OK : P::BAD],
                         "array inspected by CBQN: shape #{shape[0]}  rank #{shape[1]}  row weights #{shape[2]}"]
          refresh_history
        end
      end

      def run_all
        GUI.job(self, @out, 'CBQN run all ops') do
          res = @ops.map { |op| run_one(op) }
          @out.content = res.map { |op, _a, got, _w, same| [format('%-12s %-6s %s', op, same ? 'MATCH' : 'DIFF', got.first.to_s[0, 90]), same ? P::OK : P::BAD] } +
                         ['', "#{res.count { |r| r[4] }}/#{res.length} operations bit-exact between CBQN and Ruby"]
          refresh_history
        end
      end

      def refresh_history
        @hist.content = @cbqn.history.last(14).map { |h| "exit=#{h[:exit_status]}  bqn cli.bqn #{h[:op]} #{h[:args].join(' ')[0, 120]}  →  #{h[:stdout].lines.first.to_s.chomp[0, 60]}" }
      end
    end

    class ElfPanel < Panel
      def initialize(ww, wh)
        super(ww, wh, 'panel-elf')
        label('Elf logic inspector  (Twelf; requests go through the mh-jsonl/1 Elf backend process)', 20, 12, size: 16, bold: true)
        @decls = load_decls
        @list = add(Morphic::ListMorph.new(@decls.map { |d| d[:name] }, x: @x + 20, y: @y + 48, width: 330, height: 520, size: 11, name: 'elf-rules',
                                           on_select: ->(i, _v) { show_decl(i) }))
        @detail = textbox(20, 576, 330, 264, 'elf-decl', size: 11)
        button('Check signature (%total)', 370, 48, 230, 'btn-elf-check') { check }
        button('Run TM query', 610, 48, 150, 'btn-elf-tm') { tm }
        button('Braid derivation', 770, 48, 170, 'btn-elf-deriv') { deriv }
        button('Failed obligations', 950, 48, 190, 'btn-elf-neg') { negatives }
        button('Query DNA encode', 1150, 48, 180, 'btn-elf-dna') { dna }
        @out = textbox(370, 84, 1010, 756, 'elf-out', size: 11)
      end

      def load_decls
        Dir[File.join(ElfAdapter::ELF_DIR, '**', '*.elf')].sort.flat_map do |f|
          rel = f.delete_prefix("#{ProcessRunner::ROOT}/")
          File.readlines(f).each_with_index.filter_map do |line, i|
            m = line.match(/\A([A-Za-z][\w\/-]*) :(.*)/)
            { name: "#{m[1]}", file: rel, line: i + 1, text: line.strip } if m
          end
        end
      end

      def show_decl(i)
        d = @decls[i]
        @detail.content = ["#{d[:file]}:#{d[:line]}", ''] + d[:text].scan(/.{1,44}/)
      end

      def with_client
        c = ElfClient.new
        yield c
      ensure
        c&.close
      end

      def check
        GUI.job(self, @out, 'Elf check_signature') do
          with_client do |c|
            r = c.call('check_signature', {}, { 'timeout_s' => 60 })
            ev = r['evidence'] || {}
            @out.content = [["check_signature: #{r['ok'] ? 'OK — all %mode/%worlds/%total declarations accepted by Twelf' : 'FAILED'}", r['ok'] ? P::OK : P::BAD],
                            "twelf-server exit #{ev['exit_status']}, transcript sha256 #{ev['transcript_sha256']}", ''] +
                           ev['transcript'].to_s.lines.grep(/%total|%worlds|Loading|OK|ABORT|Error/).first(60).map(&:chomp)
          end
        end
      end

      def tm
        GUI.job(self, @out, 'Elf TM query') do
          with_client do |c|
            lines = ['State-transition query: run <fuel> (cfg scan <tape>) C N   (increment machine)', '']
            [['1011', 20], ['111', 20], ['1011', 5]].each do |inp, fuel|
              r = c.call('tm_increment', { 'input' => inp }, { 'max_steps' => fuel })
              lines << (r['ok'] ? ["input #{inp} fuel #{fuel}: #{r['result']['value']}", P::OK] : ["input #{inp} fuel #{fuel}: no derivation — #{r['error']['message']}", P::WARN])
              lines << "   C = #{r['result']['bindings']['C']}" if r['ok']
            end
            @out.content = lines
          end
        end
      end

      def deriv
        GUI.job(self, @out, 'Elf braid derivation') do
          with_client do |c|
            r = c.call('braid_inverse_derivation', { 'x' => [1, 0, 1], 'y' => [1, 1, 0] })
            v = r['result'] || {}
            @out.content = ['Derivation inspection for x=101, y=110', '',
                            'braid derivation (%solve d : braid X Y A B):'] +
                           "#{v.dig('braid_derivation', 'type')} = #{v.dig('braid_derivation', 'term')}".scan(/.{1,120}/) + ['',
                            'braid-inverse metatheorem run as a logic program (%solve e : braid-inverse D E):'] +
                           v.dig('inverse', 'type').to_s.scan(/.{1,120}/) + ['', [r['ok'] ? 'unbraid derivation obtained from the braid derivation' : "FAILED: #{r.dig('error', 'message')}", r['ok'] ? P::OK : P::BAD]]
          end
        end
      end

      def negatives
        GUI.job(self, @out, 'Elf failed obligations') do
          with_client do |c|
            lines = ['Proof obligations that are EXPECTED to fail (tests/properties/elf-negative):', '']
            Dir[File.join(ProcessRunner::ROOT, 'tests', 'properties', 'elf-negative', '*.elf')].sort.each do |f|
              r = c.call('check_file', { 'path' => f.delete_prefix("#{ProcessRunner::ROOT}/") }, { 'timeout_s' => 60 })
              t = r.dig('evidence', 'transcript').to_s
              lines << ["#{File.basename(f)}: #{r['ok'] ? 'UNEXPECTEDLY ACCEPTED' : 'rejected by Twelf (as expected)'}", r['ok'] ? P::BAD : P::OK]
              lines += t[/Error:.*?%% ABORT %%/m].to_s.lines.first(8).map { |l| "    #{l.chomp}" }
            end
            @out.content = lines
          end
        end
      end

      def dna
        GUI.job(self, @out, 'Elf DNA encode query') do
          with_client do |c|
            lines = []
            [[1, 0, 1, 1, 0, 0], [1, 0, 1]].each do |bits|
              r = c.call('dna_encode', { 'bits' => bits })
              ruby = begin
                DNA.encode2(bits)[:bases]
              rescue DNA::EncodingError => e
                "rejected (#{e.message})"
              end
              lines << "encode #{bits.join}: Elf #{r['ok'] ? r['result']['value'] : "no derivation (#{r['error']['message']})"}   Ruby #{ruby}"
            end
            @out.content = lines
          end
        end
      end
    end

    class AgdaPanel < Panel
      def initialize(ww, wh)
        super(ww, wh, 'panel-agda')
        label('Agda proof dashboard  (universal theorems; Alloy results are bounded and listed separately)', 20, 12, size: 16, bold: true)
        @agda = AgdaAdapter.new
        @status = nil
        @table = textbox(20, 48, 1360, 330, 'agda-table', size: 12)
        button('Type-check agda/Everything.agda', 20, 388, 300, 'btn-agda-check') { check }
        button('Run expected-failure modules', 330, 388, 280, 'btn-agda-neg') { negatives }
        @out = textbox(20, 424, 1360, 416, 'agda-out', size: 11)
        render_table
      end

      def render_table
        rows = [format('%-12s %-24s %-34s %s', 'invariant', 'theorem', 'source', 'verification state')]
        AgdaAdapter.theorem_table.each do |inv, name, file, line, _src|
          st = case @status
               when nil then ['not yet checked in this session', P::DIM]
               when true then ['type-checked (agda exit 0, --safe)', P::OK]
               else ['NOT verified (agda failed; see output)', P::BAD]
               end
          rows << [format('%-12s %-24s %-34s %s', inv, name, "agda/#{file}:#{line}", st[0]), st[1]]
        end
        @table.content = rows
      end

      def check
        GUI.job(self, @out, 'agda Everything.agda') do
          r = @agda.check('Everything.agda')
          @status = r[:ok]
          ev = r[:evidence]
          @out.content = [["agda Everything.agda → exit #{ev['exit_status']} (#{ev['duration_s']} s)", r[:ok] ? P::OK : P::BAD], "agda: #{@agda.version}", ''] + ev['transcript'].lines.map(&:chomp).first(40)
          render_table
        end
      end

      def negatives
        GUI.job(self, @out, 'agda expected-failure modules') do
          dir = File.join(ProcessRunner::ROOT, 'tests', 'properties', 'agda-negative')
          lines = ['Modules that MUST fail to type-check (counterexample / failure information):', '']
          Dir[File.join(dir, '*.agda')].sort.each do |f|
            res = ProcessRunner.run([@agda.agda_path, File.basename(f)], timeout_s: 300, chdir: dir)
            lines << ["#{File.basename(f)}: exit #{res[:exit_status]} #{res[:exit_status].zero? ? 'UNEXPECTEDLY ACCEPTED' : '(rejected, as expected)'}", res[:exit_status].zero? ? P::BAD : P::OK]
            lines += (res[:stdout] + res[:stderr]).lines.reject { |l| l.start_with?('Checking') }.first(4).map { |l| "    #{l.chomp}" }
          end
          @out.content = lines
        end
      end
    end

    class TuringPanel < Panel
      def initialize(ww, wh)
        super(ww, wh, 'panel-turing')
        label('Turing machine simulator  (binary increment, rules of the original JS)', 20, 12, size: 16, bold: true)
        label('input', 20, 52, color: P::DIM)
        @input = add(Morphic::TextFieldMorph.new('1011', allowed: /\A[01]\z/, x: @x + 80, y: @y + 48, width: 200, name: 'tm-input'))
        button('Load', 290, 48, 80, 'btn-tm-load') { load_input }
        button('Step', 380, 48, 80, 'btn-tm-step') { step_once }
        button('Run', 470, 48, 80, 'btn-tm-run') { @running = true }
        button('Stop', 560, 48, 80, 'btn-tm-stop') { @running = false }
        button('◀ Back', 650, 48, 90, 'btn-tm-back') { navigate(-1) }
        button('Fwd ▶', 750, 48, 90, 'btn-tm-fwd') { navigate(1) }
        button('Verify vs JS + Elf', 850, 48, 190, 'btn-tm-verify') { verify }
        label('step limit', 1060, 52, color: P::DIM)
        @limit = add(Morphic::SliderMorph.new(min: 1, max: 200, value: 50, x: @x + 1150, y: @y + 50, width: 220, name: 'tm-limit'))
        @tape = add(Morphic::TapeMorph.new(x: @x + 20, y: @y + 84, width: 1360, height: 120, name: 'tm-tape'))
        @status = textbox(20, 214, 660, 220, 'tm-status')
        @rules = textbox(700, 214, 680, 220, 'tm-rules')
        @trace = textbox(20, 444, 1360, 396, 'tm-trace', size: 11)
        @rules.content = ['transition table (state:symbol → write, move, next)'] + Turing::INCREMENT_RULES.map { |k, v| "  #{k.ljust(8)} → #{v[:write]} #{v[:move]} #{v[:next]}" }
        @running = false
        @acc = 0.0
        load_input
      end

      def load_input
        @configs = [Turing.initial_config(initial: @input.string, start: 'scan')]
        @entries = []
        @cursor = 0
        @no_rule = false
        @running = false
        show
      end

      def current = @configs[@cursor]
      def halted? = current.state == 'HALT'

      def step_once
        if @cursor < @configs.length - 1
          @cursor += 1
        elsif !halted? && current.steps < @limit.value
          st, nxt, entry = Turing.step(current, rules: Turing::INCREMENT_RULES)
          if st == :ok
            @configs << nxt
            @entries << entry
            @cursor += 1
          else
            @no_rule = true
            @running = false
          end
        else
          @running = false
        end
        show
      end

      def navigate(d)
        @cursor = (@cursor + d).clamp(0, @configs.length - 1)
        @running = false
        show
      end

      def step(dt)
        super
        return unless @running

        @acc += dt
        return if @acc < 0.25

        @acc = 0.0
        step_once
      end

      def show
        @tape.config = current
        status = if halted? then ['HALT (halt state reached)', P::OK]
                 elsif @no_rule then ['NO_RULE (no transition for state:symbol)', P::BAD]
                 elsif current.steps >= @limit.value then ['STEP_LIMIT reached', P::WARN]
                 else ['running / ready', P::TEXT]
                 end
        @status.content = ["state: #{current.state}", "head: #{current.head}", "steps: #{current.steps}", "tape: #{Turing.get_tape(current.tape)}",
                           "history position #{@cursor}/#{@configs.length - 1} (recorded configurations)", status,
                           "trace legal (re-executed from the initial configuration): #{Turing.legal_trace?(@configs, rules: Turing::INCREMENT_RULES)}"]
        @trace.content = ['#   from     read  write move to'] + @entries.each_with_index.map do |e, i|
          ["#{(i + 1).to_s.ljust(3)} #{e[:from_state].ljust(8)} #{e[:read]}     #{e[:write]}     #{e[:move]}    #{e[:to_state]}", i + 1 == @cursor ? P::WARN : P::TEXT]
        end
      end

      def verify
        GUI.job(self, @trace, 'verify TM vs JS + Elf') do
          inp = @input.string
          ruby = Turing.run(initial: inp, start: 'scan', rules: Turing::INCREMENT_RULES, max_steps: @limit.value)
          js = NodeOracle.new.call([{ id: 1, op: 'runTM', initial: inp, maxSteps: @limit.value }])['results'][0]['value']
          c = ElfClient.new
          el = c.call('tm_increment', { 'input' => inp }, { 'max_steps' => @limit.value })
          c.close
          r = { 'status' => ruby[:status], 'steps' => ruby[:steps], 'head' => ruby[:head], 'tape' => Turing.get_tape(ruby[:tape]) }
          same_js = js['status'] == r['status'] && js['steps'] == r['steps'] && js['head'] == r['head'] && js['tape'] == r['tape']
          ev = el['ok'] ? el['result']['value'] : nil
          same_elf = ev && ev['steps'] == r['steps'] && ev['output'] == r['tape']
          @trace.content = ["input #{inp}, limit #{@limit.value}", "Ruby : #{r}", "JS   : #{js}",
                            "Elf  : #{ev || el.dig('error', 'message')}", '',
                            [same_js ? 'Ruby == JS oracle (status, steps, head, tape)' : 'Ruby != JS oracle', same_js ? P::OK : P::BAD],
                            [same_elf ? 'Ruby == Elf (steps, tape)' : 'Elf: no matching derivation (see message)', same_elf ? P::OK : P::WARN]]
        end
      end
    end

    class SpiralPanel < Panel
      def initialize(ww, wh)
        super(ww, wh, 'panel-spiral')
        label('Spiral array engine  (square-spiral indexing on Z²; data layout only, not a physical simulation)', 20, 12, size: 16, bold: true)
        @engine = Spiral.new
        label('N', 20, 52, color: P::DIM)
        @slider = add(Morphic::SliderMorph.new(min: 1, max: 441, value: 49, x: @x + 50, y: @y + 50, width: 400, name: 'spiral-n',
                                               on_change: ->(_v) { refresh }))
        button('Verify bijection (Ruby + CBQN)', 470, 48, 280, 'btn-spiral-verify') { verify }
        @view = add(Morphic::SpiralMorph.new(engine: @engine, x: @x + 20, y: @y + 84, width: 760, height: 756, name: 'spiral-view'))
        @view.on_pick = ->(_gx, _gy, _k) { refresh_history }
        @info = textbox(800, 84, 580, 300, 'spiral-info')
        @hist = textbox(800, 394, 580, 446, 'spiral-history', size: 11)
        refresh
      end

      def refresh
        n = @slider.value
        @view.n = n
        rmax = Spiral.ring_coord([n - 1, 0].max)[0]
        @view.groups = Spiral.fibonacci_ring_groups([rmax, 1].max)
        (0...[n, 6].min).each { |k| @engine.map(k) }
        @info.content = ["N = #{n}, rings 0..#{rmax}",
                         "Fibonacci ring groups (scheduling batches): #{@view.groups.map { |g| g.join(',') }.join(' | ')}",
                         "position(N-1) = #{Spiral.position(n - 1)}  index(position(N-1)) = #{Spiral.index(*Spiral.position(n - 1))}",
                         "3-D layout sample (side 3): i=10 → #{Spiral.position3(10, 3)}  i=26 → #{Spiral.position3(26, 3)}",
                         'click a cell to invert its position (index lookup)']
        refresh_history
      end

      def refresh_history
        @hist.content = ['transformation history (most recent last)'] + @engine.history.last(26).map { |h| h.to_s[0, 90] }
      end

      def verify
        GUI.job(self, @info, 'verify spiral bijection (Ruby + CBQN)') do
          n = @slider.value
          rb = Spiral.verify_bijection(n)
          bq = CBQNAdapter.new.call('spiral-verify', n).first
          pos_b = CBQNAdapter.new.call('spiral', n).first
          pos_r = (0...n).map { |k| Spiral.position(k).join(',') }.join(' ')
          @info.content = ["N = #{n}", ["Ruby verify_bijection: #{rb}", rb[:ok] ? P::OK : P::BAD],
                           ["CBQN VerifyBijection: #{bq}", bq == '1' ? P::OK : P::BAD],
                           [pos_b == pos_r ? 'CBQN positions == Ruby positions (bit-exact)' : 'CBQN positions differ from Ruby', pos_b == pos_r ? P::OK : P::BAD],
                           'Universal proof: agda/Spiral/Index.agda invariantG (index ∘ position = id for all n)']
        end
      end
    end

    class CapacityPanel < Panel
      def initialize(ww, wh)
        super(ww, wh, 'panel-capacity')
        label('Computational capacity model  (assumptions are labelled; measured values come only from evidence files)', 20, 12, size: 16, bold: true)
        label('target TFLOP/s', 20, 52, color: P::DIM)
        @p = add(Morphic::SliderMorph.new(min: 1, max: 1000, value: 100, x: @x + 160, y: @y + 50, width: 300, name: 'cap-tflops', on_change: ->(_v) { refresh }))
        label('seconds t', 500, 52, color: P::DIM)
        @t = add(Morphic::SliderMorph.new(min: 0, max: 3600, value: 1, x: @x + 600, y: @y + 50, width: 300, name: 'cap-seconds', on_change: ->(_v) { refresh }))
        label('Moore scenario years', 940, 52, color: P::DIM)
        @years = add(Morphic::SliderMorph.new(min: 0, max: 40, value: 10, x: @x + 1120, y: @y + 50, width: 250, name: 'cap-years', on_change: ->(_v) { refresh }))
        @out = textbox(20, 90, 1360, 750, 'cap-out')
        refresh
      end

      def measured
        path = File.join(ProcessRunner::ROOT, 'evidence', 'benchmarks', 'results.json')
        return nil unless File.file?(path)

        JSON.parse(File.read(path))
      end

      def refresh
        mw = Capacity.model_workload(target_tflops: @p.value, seconds: @t.value)
        o = Capacity.budget(p: @p.value * 1e12, t: @t.value)
        m = measured
        lines = ['THEORETICAL (assumption, not a measurement)',
                 "  P = #{@p.value} TFLOP/s;  O = P × t = #{o} floating-point operations for t = #{@t.value} s",
                 "  modelWorkload (port of the JS): #{mw}", '',
                 "MOORE'S-LAW SCENARIO (transistor counts only; not a performance law; not guaranteed to continue)",
                 "  T(t) = T0·2^(t/τ), T0 = 1e9, τ = 2 y, t = #{@years.value} y → #{Capacity.moore_transistors(t0: 1e9, years: @years.value)} transistors", '']
        if m
          lines << "MEASURED on this machine (#{m['machine']&.fetch('cpu', '?')}; file evidence/benchmarks/results.json)"
          m.fetch('measurements', []).each { |r| lines << "  #{r['name']}: #{r['value']} #{r['unit']}  [#{r['kind']}]" }
        else
          lines << 'MEASURED: no benchmark results file present (nothing measured is shown).'
        end
        lines += ['', 'ANALYTICAL BOUNDS (idealised; speculative as models of computation)',
                  "  Landauer limit at 300 K: #{PhysicsBounds.landauer_joules_per_bit(300)} J/bit",
                  "  bits erasable with 1 J at 300 K: #{PhysicsBounds.landauer_bit_budget(1.0, 300)}",
                  "  Margolus–Levitin, 1 J mean energy: #{PhysicsBounds.margolus_levitin_ops_per_s(1.0)} ops/s",
                  "  Bremermann, 1 kg: #{PhysicsBounds.bremermann_bits_per_s(1.0)} bit/s",
                  "  Bekenstein bound, R = 1 m, E = 1 J: #{PhysicsBounds.bekenstein_bits(1.0, 1.0)} bits",
                  "  Bekenstein–Hawking entropy of 1 solar mass (1.989e30 kg): #{PhysicsBounds.black_hole_entropy(1.989e30)[1]} bits", ''] +
                 PhysicsBounds::ASSUMPTIONS.map { |a| "  * #{a}" } +
                 ['  * Bitwise operations and Turing-machine steps are not FLOPs; they are reported separately.']
        @out.content = lines
      end
    end
  end
end
