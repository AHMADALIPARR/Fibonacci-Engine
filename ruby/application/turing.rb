# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

module MorphicHelix
  # Deterministic sparse-tape Turing machine runner, ported from runTM/getTape in fibonacci_braid.js.
  # Semantics kept identical: tape is a Hash from integer cell to symbol, writing the blank deletes the
  # cell, moves are L/R/S, status is HALT, NO_RULE or STEP_LIMIT. The transition table is a Hash keyed
  # by "state:symbol", so it is functional by construction (one rule per key).
  module Turing
    INCREMENT_RULES = {
      'scan:0' => { write: '0', move: 'R', next: 'scan' },
      'scan:1' => { write: '1', move: 'R', next: 'scan' },
      'scan:_' => { write: '_', move: 'L', next: 'carry' },
      'carry:1' => { write: '0', move: 'L', next: 'carry' },
      'carry:0' => { write: '1', move: 'S', next: 'HALT' },
      'carry:_' => { write: '1', move: 'S', next: 'HALT' }
    }.freeze

    Config = Struct.new(:state, :head, :tape, :steps, keyword_init: true)

    module_function

    def initial_config(initial: '', head: 0, start: 'q0')
      tape = {}
      initial.each_char.with_index { |c, i| tape[i] = c }
      Config.new(state: start, head: head, tape: tape, steps: 0)
    end

    # One transition. Returns [:ok, new_config, trace_entry] or [:no_rule, config, nil].
    def step(cfg, rules:, blank: '_')
      symbol = cfg.tape.fetch(cfg.head, blank)
      rule = rules["#{cfg.state}:#{symbol}"]
      return [:no_rule, cfg, nil] unless rule
      raise ArgumentError, "bad move #{rule[:move].inspect}" unless %w[L R S].include?(rule[:move])

      tape = cfg.tape.dup
      prev = cfg.tape.key?(cfg.head) ? cfg.tape[cfg.head] : nil
      if rule[:write] == blank then tape.delete(cfg.head) else tape[cfg.head] = rule[:write] end
      head = cfg.head + (rule[:move] == 'R' ? 1 : rule[:move] == 'L' ? -1 : 0)
      entry = { from_state: cfg.state, head: cfg.head, read: symbol, prev_cell: prev, write: rule[:write],
                move: rule[:move], to_state: rule[:next] }
      [:ok, Config.new(state: rule[:next], head: head, tape: tape, steps: cfg.steps + 1), entry]
    end

    # Same loop as runTM, additionally recording every configuration (for reversible trace navigation).
    def run(blank: '_', initial: '', head: 0, start: 'q0', halt: 'HALT', rules:, max_steps: 10_000)
      raise ArgumentError, 'max_steps must be a nonnegative integer' unless max_steps.is_a?(Integer) && max_steps >= 0

      cfg = initial_config(initial: initial, head: head, start: start)
      configs = [cfg]
      trace = []
      while cfg.state != halt && cfg.steps < max_steps
        status, nxt, entry = step(cfg, rules: rules, blank: blank)
        return { status: 'NO_RULE', state: cfg.state, head: cfg.head, steps: cfg.steps, tape: cfg.tape, configs: configs, trace: trace } if status == :no_rule

        cfg = nxt
        configs << cfg
        trace << entry
      end
      { status: cfg.state == halt ? 'HALT' : 'STEP_LIMIT', state: cfg.state, head: cfg.head, steps: cfg.steps,
        tape: cfg.tape, configs: configs, trace: trace }
    end

    def get_tape(tape, blank: '_')
      return '' if tape.empty?

      lo, hi = tape.keys.minmax
      (lo..hi).map { |i| tape.fetch(i, blank) }.join
    end

    # Undo one recorded transition using only the trace entry (reversibility of a recorded history).
    def undo(cfg, entry, blank: '_')
      tape = cfg.tape.dup
      if entry[:prev_cell].nil? then tape.delete(entry[:head]) else tape[entry[:head]] = entry[:prev_cell] end
      Config.new(state: entry[:from_state], head: entry[:head], tape: tape, steps: cfg.steps - 1)
    end

    # Checks that a recorded trace consists of legal transitions from the given initial configuration.
    def legal_trace?(configs, rules:, blank: '_')
      configs.each_cons(2).all? do |a, b|
        status, nxt, = step(a, rules: rules, blank: blank)
        status == :ok && nxt.state == b.state && nxt.head == b.head && nxt.tape == b.tape
      end
    end
  end
end
