# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'tmpdir'
require_relative 'process_runner'

module MorphicHelix
  # Drives the Twelf server (the Elf implementation) through its documented command interface:
  #   set chatter <n> / Config.read <cfg> / Config.load / loadFile <file> / quit
  # Each query is written to a temporary .elf file containing one %query or %solve declaration and
  # loaded into a fresh server process (no unsupported runtime API is used).
  class ElfAdapter
    ELF_DIR = File.join(ProcessRunner::ROOT, 'elf')
    SOURCES = File.join(ELF_DIR, 'sources.cfg')

    Term = Struct.new(:head, :args) do
      def to_s = args.empty? ? head : "(#{head} #{args.map(&:to_s).join(' ')})"
    end

    def initialize(timeout_s: 30)
      @timeout_s = timeout_s
    end

    def twelf_path = ProcessRunner.which('twelf-server', env_var: 'MH_TWELF')

    # Loads the full signature; all %mode/%worlds/%total metatheorem checks run here.
    def check_signature
      script = "set chatter 3\nConfig.read #{SOURCES}\nConfig.load\nquit\n"
      res = ProcessRunner.run([twelf_path], stdin_data: script, timeout_s: @timeout_s, chdir: ELF_DIR)
      { ok: !res[:timed_out] && res[:stdout].include?('%% OK %%') && !res[:stdout].include?('%% ABORT %%'),
        evidence: ProcessRunner.evidence('twelf-server', res) }
    end

    def check_file(path)
      script = "set chatter 3\nConfig.read #{SOURCES}\nConfig.load\nloadFile #{path}\nquit\n"
      res = ProcessRunner.run([twelf_path], stdin_data: script, timeout_s: @timeout_s, chdir: ELF_DIR)
      { ok: !res[:timed_out] && !res[:stdout].include?('%% ABORT %%'), evidence: ProcessRunner.evidence('twelf-server', res) }
    end

    # Runs one declaration (a %query or %solve line) against the loaded signature.
    def run_decl(decl, timeout_s: @timeout_s)
      Dir.mktmpdir('mh-elf') do |dir|
        q = File.join(dir, 'query.elf')
        File.write(q, "#{decl}\n")
        script = "set chatter 1\nConfig.read #{SOURCES}\nConfig.load\nset chatter 3\nloadFile #{q}\nquit\n"
        res = ProcessRunner.run([twelf_path], stdin_data: script, timeout_s: timeout_s, chdir: ELF_DIR)
        ev = ProcessRunner.evidence('twelf-server', res)
        raise BackendError.new("twelf-server timed out after #{timeout_s}s", ev) if res[:timed_out]

        out = res[:stdout]
        tail = out.split("[Opening file #{q}]", 2)[1] || ''
        if tail.include?('%% ABORT %%')
          msg = tail[/Error:\s*\n?(.*?)\n%% ABORT %%/m, 1]&.strip || 'Twelf aborted'
          return { ok: false, error: msg, evidence: ev }
        end
        { ok: true, bindings: parse_bindings(tail), derivation: parse_solve(tail), evidence: ev }
      end
    end

    def query(goal, timeout_s: @timeout_s) = run_decl("%query 1 1 #{goal}.", timeout_s: timeout_s)
    def solve(name, goal, timeout_s: @timeout_s) = run_decl("%solve #{name} : #{goal}.", timeout_s: timeout_s)

    # ---- term encodings -------------------------------------------------------------------------
    def self.nat(n) = n.zero? ? 'z' : "(s #{nat(n - 1)})"
    def self.bits(v) = v.reverse.reduce('nil') { |acc, b| "(cons b#{b} #{acc})" }
    def self.bases(str) = str.chars.reverse.reduce('bnil') { |acc, c| "(bcons b#{c.downcase} #{acc})" }
    TSYM = { '0' => 't0', '1' => 't1', '_' => 'tb' }.freeze
    def self.tlist(chars) = chars.reverse.reduce('tnil') { |acc, c| "(tcons #{TSYM.fetch(c)} #{acc})" }

    def self.parse_term(text)
      toks = text.scan(/\(|\)|[^\s()]+/)
      raise ArgumentError, "empty term" if toks.empty?
    
      term, pos = parse_app(toks, 0)
      raise ArgumentError, "trailing tokens in term #{text.inspect}" unless pos == toks.length
    
      term
    end
    
    # application: head argument* (stops at a closing parenthesis or the end)
    def self.parse_app(toks, pos)
      head, pos = parse_arg(toks, pos)
      args = []
      while pos < toks.length && toks[pos] != ")"
        arg, pos = parse_arg(toks, pos)
        args << arg
      end
      [args.empty? ? head : Term.new(head.head, head.args + args), pos]
    end
    
    def self.parse_arg(toks, pos)
      raise ArgumentError, "unexpected end of term" if pos >= toks.length
      return [Term.new(toks[pos], []), pos + 1] unless toks[pos] == "("
    
      term, pos = parse_app(toks, pos + 1)
      raise ArgumentError, "unbalanced parentheses" unless toks[pos] == ")"
    
      [term, pos + 1]
    end
    
    def self.term_to_bits(t)
      out = []
      while t.head == 'cons'
        out << Integer(t.args[0].head.delete_prefix('b'))
        t = t.args[1]
      end
      raise ArgumentError, "not a bits term: #{t}" unless t.head == 'nil'

      out
    end

    def self.term_to_nat(t)
      n = 0
      while t.head == 's'
        n += 1
        t = t.args[0]
      end
      raise ArgumentError, "not a nat term: #{t}" unless t.head == 'z'

      n
    end

    def self.term_to_bases(t)
      out = +''
      while t.head == 'bcons'
        out << t.args[0].head.delete_prefix('b').upcase
        t = t.args[1]
      end
      raise ArgumentError, "not a bases term: #{t}" unless t.head == 'bnil'

      out
    end

    def self.term_to_tlist(t)
      out = []
      while t.head == 'tcons'
        out << TSYM.key(t.args[0].head)
        t = t.args[1]
      end
      out
    end

    # Tape string in the format of getTape (blank-trimmed at both ends, interior blanks shown as '_').
    def self.term_to_tape(t)
      left, cur, right = t.args
      cells = term_to_tlist(left).reverse + [TSYM.key(cur.head)] + term_to_tlist(right)
      s = cells.join
      s.gsub(/\A_+|_+\z/, '')
    end

    # ---- typed operations -----------------------------------------------------------------------
    def fib_word(n)
      r = query("fibword #{self.class.nat(n)} W")
      r.merge(result: r[:ok] ? self.class.term_to_bits(self.class.parse_term(r[:bindings].fetch('W'))) : nil)
    end

    def braid(x, y)
      r = query("braid #{self.class.bits(x)} #{self.class.bits(y)} A B")
      r.merge(result: r[:ok] ? %w[A B].map { |k| self.class.term_to_bits(self.class.parse_term(r[:bindings].fetch(k))) } : nil)
    end

    def unbraid(a, b)
      r = query("unbraid #{self.class.bits(a)} #{self.class.bits(b)} X Y")
      r.merge(result: r[:ok] ? %w[X Y].map { |k| self.class.term_to_bits(self.class.parse_term(r[:bindings].fetch(k))) } : nil)
    end

    def dna_encode(bits)
      r = query("encode #{self.class.bits(bits)} N")
      r.merge(result: r[:ok] ? self.class.term_to_bases(self.class.parse_term(r[:bindings].fetch('N'))) : nil)
    end

    def dna_decode(bases)
      r = query("decode #{self.class.bases(bases)} L")
      r.merge(result: r[:ok] ? self.class.term_to_bits(self.class.parse_term(r[:bindings].fetch('L'))) : nil)
    end

    # Runs the increment machine from head position 0 on the given input with a fuel (step) bound.
    def tm_increment(input, fuel)
      chars = input.chars
      tape = chars.empty? ? '(tp tnil tb tnil)' : "(tp tnil #{TSYM.fetch(chars[0])} #{self.class.tlist(chars[1..])})"
      r = query("run #{self.class.nat(fuel)} (cfg scan #{tape}) C N")
      return r.merge(result: nil) unless r[:ok]

      c = self.class.parse_term(r[:bindings].fetch('C'))
      r.merge(result: { 'status' => 'HALT', 'state' => c.args[0].head, 'steps' => self.class.term_to_nat(self.class.parse_term(r[:bindings].fetch('N'))),
                        'output' => self.class.term_to_tape(c.args[1]) })
    end

    # Derivation inspection: obtains the braid derivation, then runs the braid-inverse metatheorem on it
    # (as a logic program) to obtain the corresponding unbraid derivation.
    def braid_inverse_derivation(x, y)
      d = solve('d', "braid #{self.class.bits(x)} #{self.class.bits(y)} A B")
      return d unless d[:ok]

      term = d[:derivation].fetch(:term)
      e = solve('e', "braid-inverse (#{term}) E")
      { ok: e[:ok], braid_derivation: d[:derivation], inverse: e[:derivation], error: e[:error], evidence: e[:evidence] }
    end

    private

    def parse_bindings(tail)
      sol = tail[/---------- Solution 1 ----------\n(.*?)\n_{10,}/m, 1]
      return {} unless sol

      sol.gsub(/\s+/, ' ').strip.delete_suffix('.').split(';').to_h do |b|
        k, v = b.split('=', 2).map(&:strip)
        [k, v]
      end
    end

    def parse_solve(tail)
      m = tail.match(/%solve.*?\n OK\n(\w+) :(.*?)= (.*?)\.\n/m)
      return nil unless m

      { name: m[1], type: m[2].gsub(/\s+/, ' ').strip, term: m[3].gsub(/\s+/, ' ').strip }
    end
  end
end
