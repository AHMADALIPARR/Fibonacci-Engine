# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'digest'
require_relative 'braid'

module MorphicHelix
  # Generalised multistrand binary braid on k equal-length bit strands (rows 0..k-1, deterministic order).
  # Operators (each is a bijection on the state space, so every program is invertible):
  #   Permute(p)    new[i] = old[p[i]]                 inverse: Permute(p^-1)
  #   XorMix(s, d)  new[d] = old[d] XOR old[s], s != d inverse: XorMix(s, d) (self-inverse)
  #   Sigma(i)      rows (i, i+1): (x, y) -> (y, x XOR y)   inverse: SigmaInv(i)
  #   SigmaInv(i)   rows (i, i+1): (a, b) -> (a XOR b, a)   inverse: Sigma(i)
  # Sigma is the two-lane braid of the JS original applied to adjacent strands. These operators are a
  # constructed reversible binary system; they are not generators of the Artin braid group and do not
  # satisfy its relations in general (see docs/ARCHITECTURE.md).
  module Multistrand
    Op = Struct.new(:kind, :args) do
      def to_s
        case kind
        when :permute then "P:#{args.join(',')}"
        when :xormix then "X:#{args[0]}>#{args[1]}"
        when :sigma then "S:#{args[0]}"
        when :sigma_inv then "s:#{args[0]}"
        end
      end
    end

    module_function

    def permute(p) = Op.new(:permute, p.dup)
    def xormix(src, dst) = Op.new(:xormix, [src, dst])
    def sigma(i) = Op.new(:sigma, [i])
    def sigma_inv(i) = Op.new(:sigma_inv, [i])

    # Text form used across the Ruby/CBQN boundary: "P:2,0,1" "X:0>2" "S:1" "s:1"
    def parse_op(text)
      case text
      when /\AP:(\d+(?:,\d+)*)\z/ then permute(Regexp.last_match(1).split(',').map(&:to_i))
      when /\AX:(\d+)>(\d+)\z/ then xormix(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i)
      when /\AS:(\d+)\z/ then sigma(Regexp.last_match(1).to_i)
      when /\As:(\d+)\z/ then sigma_inv(Regexp.last_match(1).to_i)
      else raise ArgumentError, "unparseable operator #{text.inspect}"
      end
    end

    def validate_state(state)
      raise ArgumentError, 'state must have at least one strand' if state.empty?
      n = state.first.length
      state.each do |row|
        raise Braid::LengthMismatch, 'all strands must have equal length' unless row.length == n
        Braid.check_bits(row)
      end
    end

    def validate_op(op, k)
      case op.kind
      when :permute
        raise ArgumentError, "permutation #{op.args.inspect} is not a permutation of 0...#{k}" unless op.args.sort == (0...k).to_a
      when :xormix
        s, d = op.args
        raise ArgumentError, "xormix indices out of range or equal: #{op}" unless s < k && d < k && s != d
      when :sigma, :sigma_inv
        raise ArgumentError, "sigma index out of range: #{op}" unless op.args[0] + 1 < k
      end
    end

    def apply(op, state)
      validate_state(state)
      validate_op(op, state.length)
      out = state.map(&:dup)
      case op.kind
      when :permute
        out = op.args.map { |j| state[j].dup }
      when :xormix
        s, d = op.args
        out[d] = Braid.xor(state[d], state[s])
      when :sigma
        i = op.args[0]
        out[i], out[i + 1] = Braid.braid(state[i], state[i + 1])
      when :sigma_inv
        i = op.args[0]
        out[i], out[i + 1] = Braid.unbraid(state[i], state[i + 1])
      end
      out
    end

    def inverse(op)
      case op.kind
      when :permute
        inv = Array.new(op.args.length)
        op.args.each_with_index { |j, i| inv[j] = i }
        permute(inv)
      when :xormix then xormix(*op.args)
      when :sigma then sigma_inv(op.args[0])
      when :sigma_inv then sigma(op.args[0])
      end
    end

    def inverse_program(program) = program.reverse.map { |op| inverse(op) }

    def serialize(state)
      "MH1|k=#{state.length}|n=#{state.first.length}|#{state.map(&:join).join('|')}"
    end

    def deserialize(text)
      parts = text.split('|', -1)
      raise ArgumentError, 'bad serialization header' unless parts[0] == 'MH1'
      k = parts[1].delete_prefix('k=').to_i
      n = parts[2].delete_prefix('n=').to_i
      rows = parts[3..].map { |r| r.chars.map(&:to_i) }
      raise ArgumentError, 'bad serialization shape' unless rows.length == k && rows.all? { |r| r.length == n }

      rows
    end

    def state_hash(state) = Digest::SHA256.hexdigest(serialize(state))

    # Runs a program, returning the final state and the transformation history.
    def run(program, state)
      history = [{ step: 0, op: nil, hash: state_hash(state), state: state }]
      program.each_with_index do |op, i|
        state = apply(op, state)
        history << { step: i + 1, op: op.to_s, hash: state_hash(state), state: state }
      end
      { state: state, history: history }
    end

    # Cycle detection for repeated application of a whole program. Because each program is a bijection
    # on a finite state space, the orbit of any state is purely periodic: the first repeated state is the
    # start state. This is checked, not assumed: a repeat of a non-start state raises.
    def period(program, state, limit: 100_000)
      seen = { serialize(state) => 0 }
      cur = state
      (1..limit).each do |iter|
        cur = run(program, cur)[:state]
        key = serialize(cur)
        if seen.key?(key)
          raise "non-pure cycle: entered at #{seen[key]} (bijection violated)" unless seen[key].zero?

          return { period: iter, hash: state_hash(cur) }
        end
        seen[key] = iter
      end
      { period: nil, limit: limit }
    end
  end
end
