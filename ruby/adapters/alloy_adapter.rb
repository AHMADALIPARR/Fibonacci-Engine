# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'json'
require 'tmpdir'
require_relative 'process_runner'

module MorphicHelix
  # Runs Alloy 6 commands through the official command-line dispatcher (`java -jar alloy.jar exec`)
  # and compares each outcome with the `expect` annotation written in the specification.
  class AlloyAdapter
    def initialize(timeout_s: 600)
      @timeout_s = timeout_s
    end

    def java_path = ProcessRunner.which('java', env_var: 'MH_JAVA')

    def jar_path
      path = ENV.fetch('MH_ALLOY_JAR', '/opt/toolchains/org.alloytools.alloy.dist.jar')
      raise MissingTool, 'alloy (set MH_ALLOY_JAR to org.alloytools.alloy.dist.jar)' unless File.file?(path)

      path
    end

    def run(spec, out_dir)
      argv = [java_path, '-jar', jar_path, 'exec', '-c', '*', '-f', '-o', out_dir, spec]
      res = ProcessRunner.run(argv, timeout_s: @timeout_s)
      receipt_path = File.join(out_dir, 'receipt.json')
      commands = []
      if File.file?(receipt_path)
        receipt = JSON.parse(File.read(receipt_path))
        src = File.read(spec)
        receipt.fetch('commands').each do |name, cmd|
          sat = cmd.fetch('solution', []).any? { |s| (s['instances'] || []).any? }
          line = src.lines.find { |l| l.strip.start_with?(cmd['source'].to_s) } || ''
          expect = line[/expect\s+(\d+)/, 1]&.to_i
          outcome = cmd['type'] == 'check' ? (sat ? 'COUNTEREXAMPLE' : 'NO_COUNTEREXAMPLE') : (sat ? 'INSTANCE' : 'NO_INSTANCE')
          as_expected = expect.nil? ? nil : ((expect == 1) == sat)
          commands << { 'name' => name, 'type' => cmd['type'], 'source' => cmd['source'], 'overall_scope' => cmd['overall'], 'bitwidth' => cmd['bitwidth'],
                        'outcome' => outcome, 'expect' => expect, 'as_expected' => as_expected }
        end
      end
      { ok: res[:exit_status]&.zero? && commands.all? { |c| c['as_expected'] != false }, commands: commands,
        evidence: ProcessRunner.evidence('alloy', res) }
    end
  end
end
