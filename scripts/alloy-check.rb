# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# The single Alloy runner: runs every command of the given specifications with Alloy 6 through
# ruby/adapters/alloy_adapter.rb, writes the receipts and solutions to evidence/traces/alloy/<spec>/ and the
# outcomes to evidence/traces/alloy/summary.json, and exits 1 unless every command has an expectation and
# meets it. Expectations come from `expect 0|1` in the spec; the original braid_invariant.als has no such
# annotations and must stay byte-identical to the original apart from its licence header, so its two
# expectations are stated here.
#   ruby scripts/alloy-check.rb [spec.als ...]     (default: alloy/specifications/*.als)
require 'json'
require 'fileutils'
require_relative '../ruby/adapters/alloy_adapter'

ROOT = MorphicHelix::ProcessRunner::ROOT
OUT = File.join(ROOT, 'evidence', 'traces', 'alloy')
STATED = { 'braid_invariant.als' => { 'Reversible' => 'NO_COUNTEREXAMPLE', 'run$2' => 'INSTANCE' } }.freeze

specs = ARGV.empty? ? Dir[File.join(ROOT, 'alloy/specifications/*.als')].sort : ARGV.map { |a| File.expand_path(a) }
bad = 0
summary = specs.map do |spec|
  name = File.basename(spec)
  dir = File.join(OUT, File.basename(spec, '.als'))
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  r = MorphicHelix::AlloyAdapter.new.run(spec, dir)
  puts "#{name}: alloy exit #{r[:evidence]['exit_status']}"
  if r[:evidence]['exit_status'] != 0 || r[:commands].empty?
    puts r[:evidence]['transcript']
    bad = 1
  end
  r[:commands].each do |c|
    want = if c['expect'] then c['type'] == 'check' ? (c['expect'] == 1 ? 'COUNTEREXAMPLE' : 'NO_COUNTEREXAMPLE') : (c['expect'] == 1 ? 'INSTANCE' : 'NO_INSTANCE')
           else STATED.dig(name, c['name'])
           end
    ok = !want.nil? && want == c['outcome']
    bad = 1 unless ok
    c['expected_outcome'] = want
    puts format('  %-4s %-36s %-18s expected %-18s %s', ok ? 'OK' : 'FAIL', c['name'], c['outcome'], want || '(none stated)', c['source'])
  end
  { 'spec' => "alloy/specifications/#{name}", 'exit_status' => r[:evidence]['exit_status'], 'commands' => r[:commands] }
end
FileUtils.mkdir_p(OUT)
File.write(File.join(OUT, 'summary.json'), JSON.pretty_generate(summary) + "\n")
puts bad.zero? ? 'all Alloy commands met their expectations (bounded scopes only)' : 'ALLOY: unexpected outcome or missing expectation'
exit bad
