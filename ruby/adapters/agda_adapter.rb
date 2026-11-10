# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative 'process_runner'

module MorphicHelix
  # Runs the Agda type checker on the proof modules and reports per-theorem source locations.
  class AgdaAdapter
    AGDA_DIR = File.join(ProcessRunner::ROOT, 'agda')

    THEOREMS = [
      ['A', 'invariantA', 'Fibonacci/Words.agda'], ['A', 'length-fib', 'Fibonacci/Words.agda'],
      ['B', 'invariantB', 'Braid/XorBraid.agda'], ['B', 'braid-unbraid', 'Braid/XorBraid.agda'],
      ['B', 'braid-order3', 'Braid/XorBraid.agda'], ['B (Alloy)', 'reversible', 'Braid/AlloyReversible.agda'],
      ['C', 'invariantC', 'DNA/Encoding.agda'], ['C', 'encodeBits-sound', 'DNA/Encoding.agda'],
      ['D', 'xor-closed', 'Coding/Repetition.agda'], ['D', 'doubly-even', 'Coding/Repetition.agda'],
      ['D', 'min-distance-4', 'Coding/Repetition.agda'], ['D', 'corrects-single-error', 'Coding/Repetition.agda'],
      ['E', 'step-deterministic', 'Turing/Machine.agda'], ['E', 'stepR-deterministic', 'Turing/Machine.agda'],
      ['F', 'runTrace-legal', 'Turing/Trace.agda'], ['F', 'invariantF', 'Turing/Trace.agda'],
      ['F (example)', 'accepted', 'Turing/Increment.agda'], ['G', 'invariantG', 'Spiral/Index.agda'],
      ['G', 'invariantG-Fin', 'Spiral/Index.agda'], ['G', 'positionFin-injective', 'Spiral/Index.agda'],
      ['G (vectors)', 'agrees-with-ruby', 'Spiral/Vectors.agda']
    ].freeze

    def initialize(timeout_s: 600)
      @timeout_s = timeout_s
    end

    def agda_path = ProcessRunner.which('agda', env_var: 'MH_AGDA')

    def version = ProcessRunner.run([agda_path, '--version'], timeout_s: 30)[:stdout].strip

    def check(module_path = 'Everything.agda')
      res = ProcessRunner.run([agda_path, module_path], timeout_s: @timeout_s, chdir: AGDA_DIR)
      { ok: res[:exit_status]&.zero? && !res[:timed_out], evidence: ProcessRunner.evidence('agda', res) }
    end

    def self.locate(name, file)
      path = File.join(AGDA_DIR, file)
      File.foreach(path).with_index(1) { |line, no| return [file, no, line.strip] if line.lstrip.start_with?("#{name} :") }
      [file, nil, nil]
    end

    def self.theorem_table = THEOREMS.map { |inv, name, file| [inv, name, *locate(name, file)] }
  end
end
