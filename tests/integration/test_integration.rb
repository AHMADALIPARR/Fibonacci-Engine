# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Integration tests across process boundaries: Elf backend protocol and its negative controls (inputs that
# MUST be rejected), the Agda theorem table, process-group cleanup, and fail-closed behaviour when a tool is missing.
# Transcripts are written to evidence/traces/integration/.
require 'minitest/autorun'
require 'json'
require 'fileutils'
%w[process_runner cbqn_adapter elf_adapter elf_client agda_adapter alloy_adapter node_oracle_adapter].each { |f| require_relative "../../ruby/adapters/#{f}" }

class IntegrationTest < Minitest::Test
  include MorphicHelix
  ROOT = ProcessRunner::ROOT
  TRACE = File.join(ROOT, 'evidence', 'traces', 'integration')
  FileUtils.mkdir_p(TRACE)

  def save(name, obj) = File.write(File.join(TRACE, name), JSON.pretty_generate(obj) + "\n")

  def test_elf_backend_protocol
    c = ElfClient.new
    sig = c.call('check_signature')
    assert sig['ok']
    w = c.call('fib_word', { 'n' => 3 })
    assert_equal [0, 1, 0, 0, 1], w['result']['value']
    tm = c.call('tm_increment', { 'input' => '1011' }, { 'max_steps' => 10 })
    assert_equal 8, tm['result']['value']['steps']
    assert_equal '1100', tm['result']['value']['output']
    short = c.call('tm_increment', { 'input' => '1011' }, { 'max_steps' => 5 })
    refute short['ok']
    assert_equal 'no_derivation', short['error']['type']
    odd = c.call('dna_encode', { 'bits' => [1, 0, 1] })
    assert_equal 'no_derivation', odd['error']['type']
    unk = c.call('no_such_op')
    assert_equal 'unsupported_op', unk['error']['type']
    d = c.call('braid_inverse_derivation', { 'x' => [1, 0], 'y' => [1, 1] })
    assert d['ok'], d.inspect
    save('elf-protocol.json', c.log)
    c.close
  end

  def test_elf_backend_rejects_garbage_line
    out, = Open3.capture2(RbConfig.ruby, File.join(ROOT, 'ruby/adapters/elf_backend.rb'), stdin_data: "this is not json\n")
    resp = JSON.parse(out.lines.first)
    assert_equal 'protocol_error', resp['error']['type']
  end

  def test_elf_negative_controls
    elf = ElfAdapter.new(timeout_s: 120)
    results = Dir[File.join(ROOT, 'tests/properties/elf-negative/*.elf')].sort.map do |f|
      r = elf.check_file(f)
      refute r[:ok], "#{File.basename(f)} must be rejected by Twelf"
      assert_match(/Coverage error|coverage/i, r[:evidence]['transcript'])
      { file: File.basename(f), rejected: !r[:ok], evidence: r[:evidence] }
    end
    assert_equal 3, results.length
    save('elf-negative.json', results)
  end

  # Alloy and Agda are executed once per verification run, by scripts/alloy-check.rb and the agda steps of
  # scripts/verify-all.sh; they are not executed a second time here. This checks the GUI's theorem table:
  # every listed theorem must be found at a real declaration in the Agda sources.
  def test_agda_theorem_table_locates_every_theorem
    table = AgdaAdapter.theorem_table
    table.each do |inv, name, file, line, src|
      refute_nil line, "invariant #{inv}: #{name} not declared in agda/#{file}"
      assert src.start_with?("#{name} :"), src
    end
    save('agda-theorem-table.json', table)
  end

  def test_agda_sources_have_no_escape_hatches
    Dir[File.join(ROOT, 'agda/**/*.agda')].each do |f|
      src = File.read(f)
      refute_match(/\bpostulate\b/, src, f)
      refute_match(/\{!|\?\s*$/, src, f)
      assert_match(/OPTIONS --safe/, src, f)
    end
  end

  def test_missing_tool_fails_closed
    { 'MH_BQN' => -> { CBQNAdapter.new.call('fibs', 5) }, 'MH_TWELF' => -> { ElfAdapter.new.check_signature },
      'MH_AGDA' => -> { AgdaAdapter.new.check }, 'MH_JAVA' => -> { AlloyAdapter.new.run('x.als', '/tmp') },
      'MH_NODE' => -> { NodeOracle.new.call([]) } }.each do |var, call|
      old = ENV[var]
      ENV[var] = '/nonexistent/tool'
      e = assert_raises(MissingTool) { call.call }
      assert_match(/\Amissing /, e.message)
    ensure
      ENV[var] = old
    end
  end

  # A cancelled run is reported as Cancelled and leaves no process group behind.
  def test_terminate_all_stops_running_children
    t = Thread.new do
      Thread.current.report_on_exception = false
      ProcessRunner.run([ProcessRunner.which('ruby'), '-e', 'sleep 30'], timeout_s: 60)
    end
    sleep 0.05 until ProcessRunner.live.any? { |_g, (label, owner)| label == 'ruby' && owner.equal?(t) } || !t.alive?
    pgid = ProcessRunner.live.find { |_g, (_label, owner)| owner.equal?(t) }&.first
    refute_nil pgid
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ProcessRunner.terminate_all(grace_s: 2.0)
    assert_raises(Cancelled) { t.value }
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0, :<, 3.0
    refute ProcessRunner.group_alive?(pgid)
    assert_empty ProcessRunner.live
  end

  def test_elf_client_shutdown_terminates_backend
    c = ElfClient.new
    assert c.call('check_signature')['ok']
    pgid = ProcessRunner.live.keys.find { |g| ProcessRunner.live[g][0] == 'elf_backend.rb' }
    refute_nil pgid
    ProcessRunner.terminate_all(grace_s: 2.0)
    assert_raises(Cancelled) { c.call('check_signature') }
    c.close
    refute ProcessRunner.group_alive?(pgid)
  end

  def test_require_tool_script
    out, st = Open3.capture2e('sh', File.join(ROOT, 'scripts/require-tool.sh'), 'definitely-not-a-tool-mh')
    refute st.success?
    assert_equal "missing definitely-not-a-tool-mh\n", out
    _, st2 = Open3.capture2e('sh', File.join(ROOT, 'scripts/require-tool.sh'), 'sh')
    assert st2.success?
  end
end
