# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'json'
require_relative 'process_runner'

module MorphicHelix
  # Calls the JavaScript reference oracle (tests/equivalence/oracle.js), which evaluates the original
  # fibonacci_braid.js. Batch requests: an array of {id, op, ...} objects.
  class NodeOracle
    ORACLE = File.join(ProcessRunner::ROOT, 'tests', 'equivalence', 'oracle.js')

    def node_path = ProcessRunner.which('node', env_var: 'MH_NODE')

    def call(requests, timeout_s: 120)
      res = ProcessRunner.run([node_path, ORACLE], stdin_data: JSON.generate(requests), timeout_s: timeout_s)
      raise BackendError.new("node oracle failed (exit #{res[:exit_status]}): #{res[:stderr]}", ProcessRunner.evidence('node', res)) unless res[:exit_status]&.zero?

      JSON.parse(res[:stdout])
    end
  end
end
