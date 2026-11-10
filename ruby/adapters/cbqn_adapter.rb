# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'process_runner'

module MorphicHelix
  # Ruby -> CBQN process boundary. Every call runs `bqn cbqn/cli.bqn <op> <args…>`.
  class CBQNAdapter
    CLI = File.join(ProcessRunner::ROOT, 'cbqn', 'cli.bqn')

    attr_reader :history

    def initialize(timeout_s: 60)
      @timeout_s = timeout_s
      @history = []
    end

    def bqn_path = ProcessRunner.which('bqn', env_var: 'MH_BQN')

    def version
      res = ProcessRunner.run([bqn_path, '-p', '•Version'], timeout_s: @timeout_s)
      res[:stdout].strip
    end

    def call(op, *args)
      ProcessRunner.require_file!(CLI, 'cbqn/cli.bqn')
      argv = [bqn_path, CLI, op, *args.map(&:to_s)]
      res = ProcessRunner.run(argv, timeout_s: @timeout_s, chdir: File.dirname(CLI))
      ev = ProcessRunner.evidence('cbqn', res)
      @history << { op: op, args: args.map(&:to_s), exit_status: res[:exit_status], stdout: res[:stdout], stderr: res[:stderr] }
      raise BackendError.new("CBQN timed out after #{@timeout_s}s", ev) if res[:timed_out]
      raise BackendError.new("CBQN #{op} failed (exit #{res[:exit_status]}): #{res[:stderr].lines.first(3).join.strip}", ev) unless res[:exit_status]&.zero?

      res[:stdout].lines.map(&:chomp)
    end

    # Typed helpers
    def bits(str) = str.chars.map(&:to_i)
    def rows(line) = line.split(',').map { |r| bits(r) }
    def ints(line) = line.split.map { |t| Integer(t) }

    def number(line)
      Float(line).then { |f| f == f.floor && !line.include?('.') && !line.include?('e') ? Integer(line) : f }
    end
  end
end
