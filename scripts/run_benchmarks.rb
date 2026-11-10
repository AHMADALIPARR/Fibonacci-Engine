# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Benchmark harness: runs the CBQN, Node (original JS) and Ruby benchmarks, records the machine and the raw
# output, and writes evidence/benchmarks/results.json. Only measured numbers are written.
#   ruby scripts/run_benchmarks.rb [samples]
require 'json'
require 'open3'
require 'fileutils'
require 'digest'
require 'etc'
require_relative '../ruby/adapters/process_runner'
%w[braid coding multistrand spiral turing fibonacci].each { |f| require_relative "../ruby/application/#{f}" }

include MorphicHelix
ROOT = ProcessRunner::ROOT
OUT = File.join(ROOT, 'evidence', 'benchmarks')
FileUtils.mkdir_p(OUT)
SAMPLES = Integer(ARGV[0] || 7)

def sh(cmd)
  out, st = Open3.capture2e(*cmd)
  [out, st.exitstatus]
end

def lines_to_measurements(text, source)
  text.lines.map(&:chomp).reject(&:empty?).map do |l|
    name, med, min, elems, samples = l.split("\t")
    med = Float(med)
    { 'name' => name, 'source' => source, 'value' => med, 'unit' => 's', 'min_s' => Float(min), 'elements' => Integer(elems),
      'samples' => Integer(samples), 'ns_per_element' => med * 1e9 / Integer(elems), 'kind' => 'measured wall-clock (median of samples)' }
  end
end

machine = {
  'cpu' => File.read('/proc/cpuinfo')[/model name\s*:\s*(.+)/, 1],
  'logical_cpus' => Etc.nprocessors,
  'mem_total' => File.read('/proc/meminfo')[/MemTotal:\s*(.+)/, 1],
  'kernel' => sh(%w[uname -srm])[0].strip,
  'os' => File.read('/etc/os-release')[/PRETTY_NAME="(.+)"/, 1],
  'lscpu' => sh(['lscpu'])[0],
  'load_average_at_start' => File.read('/proc/loadavg').strip,
  'background_note' => 'Shared VM. Top CPU consumers at start are listed in top_processes_at_start; any busy process competes for cores.',
  'top_processes_at_start' => sh(%w[ps -eo pid,pcpu,comm --sort=-pcpu])[0].lines.first(6).map(&:strip),
  'versions' => { 'bqn' => File.realpath(ProcessRunner.which('bqn')), 'node' => sh([ProcessRunner.which('node'), '--version'])[0].strip,
                  'ruby' => RUBY_DESCRIPTION }
}

bqn = ProcessRunner.which('bqn')
node = ProcessRunner.which('node')
cb_out, cb_st = Open3.capture2e(bqn, 'arrays/bench.bqn', SAMPLES.to_s, chdir: File.join(ROOT, 'cbqn'))
cb_exit = cb_st.exitstatus
File.write(File.join(OUT, 'cbqn.tsv'), cb_out)
abort "CBQN benchmark failed (exit #{cb_exit}):\n#{cb_out}" unless cb_exit.zero?
js_out, js_exit = sh([node, File.join(ROOT, 'scripts', 'bench_js.js'), SAMPLES.to_s])
File.write(File.join(OUT, 'node.tsv'), js_out)
abort "Node benchmark failed (exit #{js_exit}):\n#{js_out}" unless js_exit.zero?

def rbench(name, inner, elems)
  yield
  t = Array.new(SAMPLES) do
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    inner.times { yield }
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) / inner
  end.sort
  med = t.length.odd? ? t[t.length / 2] : (t[t.length / 2 - 1] + t[t.length / 2]) / 2
  "#{name}\t#{med}\t#{t.first}\t#{elems}\t#{SAMPLES}"
end
rng = Random.new(20_261_110)
n = 1 << 20
x = Array.new(n) { rng.rand(2) }
y = Array.new(n) { rng.rand(2) }
st = Array.new(8) { Array.new(131_072) { rng.rand(2) } }
prog = %w[P:3,0,7,1,6,2,5,4 X:0>5 S:2 X:6>1 s:4 P:1,2,3,4,5,6,7,0].map { |t| Multistrand.parse_op(t) }
rb = []
rb << rbench('ruby.braid_1M', 3, n) { Braid.braid(x, y) }
rb << rbench('ruby.roundtrip_1M', 3, n) { Braid.unbraid(*Braid.braid(x, y)) }
rb << rbench('ruby.rep4_encode_262144', 3, 262_144) { Coding.encode_rep4(x.first(262_144)) }
rb << rbench('ruby.fibonacci_words_24', 3, 121_393) { Fibonacci.words(24) }
rb << rbench('ruby.ms_run_6ops_8x131072', 2, 8 * 131_072) { prog.reduce(st) { |s, op| Multistrand.apply(op, s) } }
rb << rbench('ruby.runTM_1011', 2000, 8) { Turing.run(initial: '1011', start: 'scan', rules: Turing::INCREMENT_RULES) }
rb << rbench('ruby.spiral_position_65536', 2, 65_536) { (0...65_536).each { |k| Spiral.position(k) } }
rb_out = rb.join("\n") + "\n"
File.write(File.join(OUT, 'ruby.tsv'), rb_out)

ms = lines_to_measurements(cb_out, 'cbqn') + lines_to_measurements(js_out, 'node (original JS)') + lines_to_measurements(rb_out, 'ruby')
by = ms.to_h { |m| [m['name'], m['value']] }
ratio = lambda do |name, a, b|
  { 'name' => name, 'value' => by.fetch(a) / by.fetch(b), 'unit' => 'x', 'kind' => "derived ratio #{a} / #{b}" }
end
derived = [
  ratio.call('speedup.cbqn_array_vs_scalar_each', 'braid.scalar_each', 'braid.array_primitive'),
  ratio.call('speedup.cbqn_batched_vs_per_row', 'batch.per_row_calls_256x4096', 'batch.one_call_256x4096'),
  ratio.call('cost.cbqn_validation_overhead', 'braid.validated_Braid', 'braid.array_primitive'),
  ratio.call('speedup.cbqn_vs_original_js_braid', 'js.braid_1M', 'braid.validated_Braid'),
  ratio.call('speedup.cbqn_vs_ruby_braid', 'ruby.braid_1M', 'braid.validated_Braid'),
  ratio.call('speedup.cbqn_vs_ruby_multistrand', 'ruby.ms_run_6ops_8x131072', 'reversible.ms_run_6ops_8x131072')
]
bitops = { 'name' => 'throughput.cbqn_xor_bit_ops_per_s', 'value' => n / by.fetch('braid.array_primitive'), 'unit' => 'bit-XOR/s',
           'kind' => 'derived from braid.array_primitive; bitwise operations, NOT floating-point operations (FLOPs)' }
derived += [
  { 'name' => 'throughput.cbqn_measured_flop_per_s', 'value' => 2.0 * n / by.fetch('flop.f64_multiply_add_1M'), 'unit' => 'FLOP/s',
    'kind' => 'derived from flop.f64_multiply_add_1M (2 float64 FLOP per element: one multiply, one add)' },
  { 'name' => 'throughput.cbqn_int_add_per_s', 'value' => n / by.fetch('int.i16_add_1M'), 'unit' => 'int-add/s', 'kind' => 'derived from int.i16_add_1M (integer, not FLOPs)' },
  { 'name' => 'bandwidth.cbqn_reverse_copy', 'value' => 2.0 * 8 * 16_777_216 / by.fetch('mem.f64_reverse_copy_16M') / 1e9, 'unit' => 'GB/s',
    'kind' => 'derived from mem.f64_reverse_copy_16M counting 8 B read + 8 B written per element (effective, not peak)' },
  { 'name' => 'simulation.js_tm_steps_per_s', 'value' => 8 / by.fetch('js.runTM_1011'), 'unit' => 'TM steps/s', 'kind' => 'derived: 8 steps per runTM(1011) of the original JS' },
  { 'name' => 'simulation.ruby_tm_steps_per_s', 'value' => 8 / by.fetch('ruby.runTM_1011'), 'unit' => 'TM steps/s', 'kind' => 'derived: 8 steps per Turing.run(1011) in Ruby (records full history)' }
]
results = {
  'schema' => 'morphic-helix/benchmarks/1', 'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'), 'samples' => SAMPLES,
  'machine' => machine, 'measurements' => ms + derived + [bitops],
  'raw_files' => %w[cbqn.tsv node.tsv ruby.tsv].to_h { |f| [f, Digest::SHA256.file(File.join(OUT, f)).hexdigest] },
  'notes' => ['Medians of SAMPLES samples; each sample is the mean over an inner repetition count.',
              'XOR/bit throughput is bitwise work, not FLOPs. No number here is a physical or Moore-law projection.']
}
File.write(File.join(OUT, 'results.json'), JSON.pretty_generate(results) + "\n")
puts "wrote evidence/benchmarks/results.json (#{results['measurements'].length} entries)"
(ms + derived + [bitops]).each { |m| puts format('%-44s %14.6g %s', m['name'], m['value'], m['unit']) }
