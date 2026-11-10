# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Elf logical backend process. Reads mh-jsonl/1 requests (one JSON object per line) on stdin and writes
# one response per line on stdout. Every operation is executed by twelf-server through ElfAdapter.
#   ruby ruby/adapters/elf_backend.rb
require 'json'
require_relative '../protocol/message'
require_relative 'elf_adapter'

module MorphicHelix
  class ElfBackend
    OPS = %w[check_signature fib_word braid unbraid dna_encode dna_decode tm_increment braid_inverse_derivation check_file].freeze

    def initialize
      @elf = nil
    end

    def handle(req)
      limits = req['limits']
      @elf = ElfAdapter.new(timeout_s: limits['timeout_s'])
      inp = req['input']
      r = case req['op']
          when 'check_signature' then @elf.check_signature
          when 'check_file' then @elf.check_file(File.expand_path(inp.fetch('path'), ProcessRunner::ROOT))
          when 'fib_word' then @elf.fib_word(Integer(inp.fetch('n')))
          when 'braid' then @elf.braid(inp.fetch('x'), inp.fetch('y'))
          when 'unbraid' then @elf.unbraid(inp.fetch('a'), inp.fetch('b'))
          when 'dna_encode' then @elf.dna_encode(inp.fetch('bits'))
          when 'dna_decode' then @elf.dna_decode(inp.fetch('bases'))
          when 'tm_increment' then @elf.tm_increment(inp.fetch('input'), Integer(limits.fetch('max_steps')))
          when 'braid_inverse_derivation' then @elf.braid_inverse_derivation(inp.fetch('x'), inp.fetch('y'))
          else
            return Protocol.response(req, ok: false, error: { 'type' => 'unsupported_op', 'message' => "unsupported op #{req['op']}; supported: #{OPS.join(', ')}" })
          end
      result = r.reject { |k, _| %i[evidence ok error].include?(k) }
      result[:value] = result.delete(:result) if result.key?(:result)
      Protocol.response(req, ok: r[:ok], result: r[:ok] ? JSON.parse(JSON.generate(result)) : nil,
                             error: r[:ok] ? nil : { 'type' => 'no_derivation', 'message' => r[:error].to_s },
                             evidence: r[:evidence])
    rescue MissingTool => e
      Protocol.response(req, ok: false, error: { 'type' => 'missing_tool', 'message' => e.message })
    rescue BackendError => e
      Protocol.response(req, ok: false, error: { 'type' => 'backend_error', 'message' => e.message }, evidence: e.evidence)
    rescue KeyError, ArgumentError, TypeError => e
      Protocol.response(req, ok: false, error: { 'type' => 'bad_input', 'message' => e.message })
    end

    def serve(input = $stdin, output = $stdout)
      output.sync = true
      input.each_line do |line|
        next if line.strip.empty?

        begin
          req = Protocol.decode_request(line)
          output.write(Protocol.encode(handle(req)))
        rescue Protocol::ProtocolError => e
          output.write(Protocol.encode({ 'protocol' => Protocol::VERSION, 'id' => nil, 'op' => nil, 'ok' => false, 'result' => nil,
                                         'error' => { 'type' => 'protocol_error', 'message' => e.message }, 'evidence' => nil }))
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # SIGTERM from the orchestrator's shutdown raises SignalException (Ruby default); ProcessRunner.run then
  # kills the twelf-server group it is waiting on, and this hook stops anything still registered.
  at_exit { MorphicHelix::ProcessRunner.terminate_all(grace_s: 1.0) }
  MorphicHelix::ElfBackend.new.serve
end
