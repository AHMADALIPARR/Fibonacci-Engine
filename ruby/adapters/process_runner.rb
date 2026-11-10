# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require 'open3'
require 'digest'

module MorphicHelix
  # Missing interpreter or binary: the operation fails loudly. There is no fallback path.
  class MissingTool < StandardError
    attr_reader :tool

    def initialize(tool)
      @tool = tool
      super("missing #{tool}")
    end
  end

  class BackendError < StandardError
    attr_reader :evidence

    def initialize(message, evidence = nil)
      @evidence = evidence
      super(message)
    end
  end

  # Raised when a running external process was terminated by ProcessRunner.terminate_all (application
  # shutdown or panel close). The result of a cancelled run is never shown as a tool result.
  class Cancelled < StandardError; end

  module ProcessRunner
    ROOT = File.expand_path('../..', __dir__)

    # Every child process group started by this Ruby process, keyed by group id. Used to terminate all
    # children on shutdown so that no agda / twelf-server / bqn / node / java process is orphaned.
    @live = {}
    @cancelled = {}
    @lock = Mutex.new

    class << self
      # label: tool name; the registering thread is recorded so one GUI job's processes can be stopped alone.
      def register(pgid, label)
        @lock.synchronize { @live[pgid] = [label, Thread.current] }
      end

      def unregister(pgid)
        @lock.synchronize do
          @live.delete(pgid)
          @cancelled.delete(pgid)
        end
      end

      def cancelled?(pgid) = @lock.synchronize { @cancelled.key?(pgid) }

      def live = @lock.synchronize { @live.dup }

      # TERM to every registered process group, then KILL to any group still present after grace_s.
      # Safe to call from an at_exit hook. (Signal handlers must not call it: they only set a flag.)
      def terminate_all(grace_s: 2.0) = terminate(grace_s) { |_g, _owner| true }

      # Same, restricted to the groups started by one thread (one GUI job).
      def terminate_thread(thread, grace_s: 2.0) = terminate(grace_s) { |_g, owner| owner.equal?(thread) }

      def terminate(grace_s)
        groups = @lock.synchronize do
          sel = @live.select { |g, (_label, owner)| yield(g, owner) }.keys
          sel.each { |g| @cancelled[g] = true }
          sel
        end
        return [] if groups.empty?

        groups.each { |g| signal_group('TERM', g) }
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace_s
        until groups.none? { |g| group_alive?(g) } || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.05
        end
        groups.each { |g| signal_group('KILL', g) if group_alive?(g) }
        groups
      end

      def signal_group(sig, pgid)
        Process.kill(sig, -pgid)
      rescue Errno::ESRCH, Errno::EPERM
        nil # the group has already exited
      end

      def group_alive?(pgid)
        Process.kill(0, -pgid)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end

    module_function

    # Locates an executable on PATH (an explicit absolute path in ENV[env_var] is honoured if executable).
    def which(tool, env_var: nil)
      if env_var && ENV[env_var] && !ENV[env_var].empty?
        path = ENV[env_var]
        return path if File.executable?(path)

        raise MissingTool, tool
      end
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
        p = File.join(dir, tool)
        return p if File.file?(p) && File.executable?(p)
      end
      raise MissingTool, tool
    end

    def require_file!(path, label)
      raise MissingTool, label unless File.file?(path)

      path
    end

    # Runs argv with a wall-clock timeout; the whole process group is killed when the limit is hit.
    # The group is registered while it runs so terminate_all can stop it; a run stopped that way raises
    # Cancelled instead of returning a partial result.
    def run(argv, stdin_data: '', timeout_s: 30, chdir: ROOT)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      out = +''
      err = +''
      status = nil
      timed_out = false
      pgid = nil
      Open3.popen3(*argv, chdir: chdir, pgroup: true) do |i, o, e, th|
        pgid = th.pid
        ProcessRunner.register(pgid, File.basename(argv.first.to_s))
        begin
          i.write(stdin_data)
        rescue Errno::EPIPE
          nil # the child exited without reading its input; its exit status and stderr are reported below
        end
        i.close
        completed = false
        begin
          readers = { o => out, e => err }
          deadline = t0 + timeout_s
          until readers.empty?
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            if remaining <= 0
              timed_out = true
              ProcessRunner.signal_group('KILL', th.pid)
              break
            end
            ready = IO.select(readers.keys, nil, nil, [remaining, 0.5].min)
            next unless ready

            ready[0].each do |io|
              chunk = io.read_nonblock(65_536, exception: false)
              if chunk.nil?
                readers.delete(io)
              elsif chunk != :wait_readable
                readers[io] << chunk
              end
            end
          end
          status = th.value
          completed = true
        ensure
          # Interrupted (exception, signal, killed thread): never leave the child group running.
          ProcessRunner.signal_group('KILL', th.pid) unless completed
          ProcessRunner.unregister(th.pid) unless completed
        end
      end
      cancelled = pgid && ProcessRunner.cancelled?(pgid)
      ProcessRunner.unregister(pgid) if pgid
      raise Cancelled, "#{File.basename(argv.first.to_s)} was terminated (application shutdown or panel closed)" if cancelled

      dt = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      { argv: argv, stdout: out, stderr: err, exit_status: status&.exitstatus, timed_out: timed_out,
        duration_s: dt.round(6), transcript_sha256: Digest::SHA256.hexdigest(out + err) }
    end

    def evidence(tool, res, transcript_limit: 20_000)
      text = res[:stdout] + res[:stderr]
      { 'tool' => tool, 'argv' => res[:argv], 'exit_status' => res[:exit_status], 'timed_out' => res[:timed_out],
        'duration_s' => res[:duration_s], 'transcript_sha256' => res[:transcript_sha256],
        'transcript' => text.length > transcript_limit ? text[0, transcript_limit] + "\n[transcript truncated for transport; sha256 covers full text]" : text }
    end
  end
end
