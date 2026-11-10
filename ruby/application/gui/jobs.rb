# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

require_relative '../../morphic/world'
require_relative '../../adapters/process_runner'

module MorphicHelix
  module GUI
    # Background jobs for GUI actions that run external tools (agda, twelf-server, bqn, node). A job runs on
    # its own Ruby thread so the GTK main loop keeps drawing and keeps answering the window's close button.
    # The job's output reaches its TextMorph through TextMorph#content=, which queues the change for the main
    # thread. One job per panel at a time; a second click while one runs is refused with a visible message.
    # Cancelling a job (panel close, application shutdown) terminates the job's child process groups.
    module Jobs
      Job = Struct.new(:panel, :label, :thread, :started)

      @jobs = {} # panel name => Job (main thread only)

      class << self
        def running(panel_name) = @jobs[panel_name]
        def idle? = @jobs.empty?

        def start(panel_name, text_morph, label, &work)
          if (j = @jobs[panel_name])
            text_morph.content = text_morph.lines +
                                 [["BUSY: \"#{j.label}\" is still running (#{(now - j.started).round(1)} s); this click was not run.", Morphic::Palette::WARN]]
            return nil
          end
          text_morph.content = [["RUNNING: #{label} …", Morphic::Palette::WARN]]
          job = Job.new(panel_name, label, nil, now)
          job.thread = Thread.new do
            Thread.current.report_on_exception = false
            report(text_morph, label, &work)
          ensure
            Morphic.defer { @jobs.delete(panel_name) if @jobs[panel_name].equal?(job) }
          end
          @jobs[panel_name] = job
        end

        # Runs one job body; every outcome is shown (nothing is swallowed).
        def report(text_morph, label)
          yield
        rescue MissingTool => e
          text_morph.content = [["FAILED: #{e.message}", Morphic::Palette::BAD], 'The toolchain is not installed; nothing was run and no result is shown.']
        rescue Cancelled => e
          text_morph.content = [["CANCELLED: #{label}: #{e.message}", Morphic::Palette::WARN]]
        rescue StandardError => e
          ev = e.respond_to?(:evidence) && e.evidence ? e.evidence['transcript'].to_s.lines.first(20).map(&:chomp) : []
          text_morph.content = [["ERROR: #{e.class}: #{e.message}", Morphic::Palette::BAD]] + ev + e.backtrace.to_a.first(4)
        end

        # Cancels the panel's job: terminates the child process groups started by its thread, then waits for it.
        def cancel(panel_name, grace_s: 2.0)
          j = @jobs.delete(panel_name) or return
          ProcessRunner.terminate_thread(j.thread, grace_s: grace_s)
          j.thread.join(grace_s + 1.0) || j.thread.kill
        end

        def cancel_all(grace_s: 2.0)
          @jobs.keys.each { |k| cancel(k, grace_s: grace_s) }
          ProcessRunner.terminate_all(grace_s: grace_s)
        end

        def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
