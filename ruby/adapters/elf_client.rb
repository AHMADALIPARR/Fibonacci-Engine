# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'open3'
require 'json'
require_relative '../protocol/message'
require_relative 'process_runner'

module MorphicHelix
  # Orchestrator side of the Elf process boundary: spawns ruby/adapters/elf_backend.rb once and exchanges
  # mh-jsonl/1 lines with it.
  class ElfClient
    BACKEND = File.join(__dir__, 'elf_backend.rb')

    attr_reader :log

    def initialize
      ProcessRunner.which('twelf-server', env_var: 'MH_TWELF') # fail loudly before spawning anything
      in_r, @stdin = IO.pipe
      @stdout, out_w = IO.pipe
      # Own process group, registered with ProcessRunner, so application shutdown terminates the backend
      # (the backend in turn terminates its twelf-server children on SIGTERM).
      @pid = Process.spawn(RbConfig.ruby, BACKEND, in: in_r, out: out_w, pgroup: true)
      in_r.close
      out_w.close
      ProcessRunner.register(@pid, 'elf_backend.rb')
      @seq = 0
      @log = []
    end

    def call(op, input = {}, limits = {})
      @seq += 1
      req = Protocol.request(id: "elf-#{@seq}", op: op, input: input, limits: limits)
      begin
        @stdin.write(Protocol.encode(req))
        @stdin.flush
        line = @stdout.gets
      rescue Errno::EPIPE, IOError
        line = nil
      end
      if line.nil?
        raise Cancelled, 'Elf backend was terminated (application shutdown or panel closed)' if ProcessRunner.cancelled?(@pid)

        raise BackendError, 'Elf backend exited or closed its pipes'
      end
      resp = Protocol.decode_response(line)
      raise Protocol::ProtocolError, "response id #{resp['id']} does not match #{req['id']}" unless resp['id'] == req['id']

      @log << { request: req, response: resp }
      resp
    end

    # Closes the request pipe (the backend exits at end of input) and reaps the backend. If it has not
    # exited within timeout_s its process group is killed. Returns the Process::Status.
    def close(timeout_s: 10)
      @stdin.close unless @stdin.closed?
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_s
      status = nil
      loop do
        _, status = Process.wait2(@pid, Process::WNOHANG)
        break if status
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          ProcessRunner.signal_group('KILL', @pid)
          _, status = Process.wait2(@pid)
          break
        end
        sleep 0.02
      end
      status
    rescue Errno::ECHILD
      nil # already reaped
    ensure
      @stdout.close unless @stdout.closed?
      ProcessRunner.unregister(@pid)
    end
  end
end
