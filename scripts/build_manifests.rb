# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Writes the machine-readable manifests:
#   evidence/manifests/provenance.json    original archive inventory, toolchains (source, version, sha256/commit)
#   evidence/manifests/verification.json  every row of evidence/verification/checks.tsv with the log's sha256
#   evidence/manifests/files.sha256       sha256 of every file in the repository, except this file itself and the two
#                                         files verify-all.sh finishes writing after this step runs:
#                                         evidence/verification/checks.tsv and evidence/verification/logs/manifests.log
require 'json'
require 'digest'
require 'zlib'
require 'open3'
ROOT = File.expand_path('..', __dir__)
MAN = File.join(ROOT, 'evidence', 'manifests')
Dir.mkdir(MAN) unless Dir.exist?(MAN)
def sha(path) = Digest::SHA256.file(path).hexdigest
# A tool that cannot be started stops the manifest build (Errno::ENOENT propagates): nothing is recorded
# for a tool that is not there.
def cmd(*argv)
  out, st = Open3.capture2e(*argv)
  { 'argv' => argv, 'exit' => st.exitstatus, 'output' => out.strip }
end

# Minimal reader of the ZIP central directory (stored entry metadata only; extraction is not needed here).
def zip_entries(path)
  data = File.binread(path)
  eocd = data.rindex("PK\x05\x06".b) or raise 'no end-of-central-directory record'
  count, _size, off = data[eocd + 10, 10].unpack('vVV')
  entries = []
  count.times do
    raise 'bad central directory' unless data[off, 4] == "PK\x01\x02".b

    method, time, date, crc, csize, usize, nlen, xlen, clen = data[off + 10, 24].unpack('vvvVVVvvv')
    lho = data[off + 42, 4].unpack1('V')
    name = data[off + 46, nlen].force_encoding('UTF-8')
    lnlen, lxlen = data[lho + 26, 4].unpack('vv')
    raw = data[lho + 30 + lnlen + lxlen, csize]
    body = method == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(raw) : raw
    raise "crc mismatch for #{name}" unless Zlib.crc32(body) == crc

    entries << { 'name' => name, 'size' => usize, 'compressed_size' => csize, 'method' => method == 8 ? 'deflate' : (method.zero? ? 'stored' : method),
                 'crc32' => format('%08x', crc), 'sha256' => name.end_with?('/') ? nil : Digest::SHA256.hexdigest(body),
                 'dos_datetime' => format('%04d-%02d-%02d %02d:%02d:%02d', 1980 + (date >> 9), (date >> 5) & 15, date & 31, time >> 11, (time >> 5) & 63, (time & 31) * 2) }
    off += 46 + nlen + xlen + clen
  end
  entries
end

zip = File.join(ROOT, 'source/original-archive/fibonacci_braid_engine.zip')
pristine = File.join(ROOT, 'source/original-archive/pristine')
entries = zip_entries(zip)
entries.each do |e|
  next unless e['sha256']

  p = File.join(pristine, e['name'])
  e['pristine_copy'] = File.file?(p) && sha(p) == e['sha256'] ? "source/original-archive/pristine/#{e['name']} (byte-identical)" : 'MISMATCH'
end

dpkg = %w[ruby ruby-gtk3 agda-bin agda-stdlib openjdk-21-jre-headless nodejs xvfb imagemagick openbox xdotool wmctrl build-essential libgmp-dev].to_h do |p|
  r = cmd('dpkg-query', '-W', '-f=${Version}', p)
  [p, r['exit']&.zero? ? r['output'] : 'not installed via dpkg']
end
git = ->(dir) { cmd('git', '-C', dir, 'rev-parse', 'HEAD')['output'] }
prov = {
  'schema' => 'morphic-helix/provenance/1', 'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
  'original_archive' => { 'path' => 'source/original-archive/fibonacci_braid_engine.zip', 'received_as' => 'b3c88e301b2ccde8bd946b981c16a1dd10ce96a0a89a2d0bd959c2611ee7e763.zip',
                          'size' => File.size(zip), 'sha256' => sha(zip), 'entries' => entries },
  'licence' => { 'file' => 'LICENSE', 'sha256' => sha(File.join(ROOT, 'LICENSE')), 'source' => 'https://www.gnu.org/licenses/agpl-3.0.txt',
                 'spdx' => 'AGPL-3.0-only' },
  'toolchains' => {
    'ruby' => { 'version' => RUBY_DESCRIPTION, 'source' => 'Debian package ruby', 'dpkg' => dpkg['ruby'] },
    'ruby-gtk3' => { 'source' => 'Debian package ruby-gtk3', 'dpkg' => dpkg['ruby-gtk3'] },
    'node' => { 'version' => cmd('node', '--version')['output'], 'source' => 'preinstalled on the build machine', 'path' => cmd('sh', '-c', 'command -v node')['output'] },
    'agda' => { 'version' => cmd('agda', '--version')['output'], 'source' => 'Debian package agda-bin', 'dpkg' => dpkg['agda-bin'],
                'note' => 'proof modules use only Agda.Builtin.*; agda-stdlib is installed but not imported' },
    'java' => { 'version' => cmd('java', '-version')['output'].lines.first&.strip, 'source' => 'Debian package openjdk-21' },
    'alloy' => { 'version' => '6.2.0', 'path' => '/opt/toolchains/org.alloytools.alloy.dist.jar', 'sha256' => sha('/opt/toolchains/org.alloytools.alloy.dist.jar'),
                 'source' => 'https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v6.2.0/org.alloytools.alloy.dist.jar' },
    'cbqn' => { 'source' => 'https://github.com/dzaima/CBQN.git', 'commit' => git.call('/opt/toolchains/CBQN'), 'build' => 'make -j8 o3',
                'bytecode_submodule_commit' => git.call('/opt/toolchains/CBQN/build/bytecodeSubmodule'),
                'binary_sha256' => sha('/opt/toolchains/CBQN/BQN'), 'path' => '/usr/local/bin/bqn -> /opt/toolchains/CBQN/BQN' },
    'twelf' => { 'source' => 'https://github.com/standardml/twelf.git', 'commit' => git.call('/opt/toolchains/twelf-src'), 'build' => 'make mlton',
                 'banner' => cmd('sh', '-c', 'echo quit | twelf-server | head -1')['output'],
                 'binary_sha256' => sha(File.realpath(cmd('sh', '-c', 'command -v twelf-server')['output'])),
                 'not_used' => { 'file' => '/opt/toolchains/twelf-linux-1.7.1.tar.gz', 'sha256' => sha('/opt/toolchains/twelf-linux-1.7.1.tar.gz'),
                                 'reason' => 'release binary is a 32-bit i386 ELF and failed to execute ("No such file or directory"); Twelf was built from source instead' } },
    'mlton' => { 'version' => cmd('sh', '-c', 'mlton 2>&1 | head -1')['output'], 'file' => '/opt/toolchains/mlton-20241230-1.amd64-linux.ubuntu-24.04_glibc2.39.tgz',
                 'sha256' => sha('/opt/toolchains/mlton-20241230-1.amd64-linux.ubuntu-24.04_glibc2.39.tgz'),
                 'source' => 'https://github.com/MLton/mlton/releases/download/on-20241230-release/mlton-20241230-1.amd64-linux.ubuntu-24.04_glibc2.39.tgz',
                 'role' => 'build-time only (compiles Twelf)' },
    'dpkg_versions' => dpkg
  },
  'build_machine' => { 'os' => File.read('/etc/os-release')[/PRETTY_NAME="(.+)"/, 1], 'kernel' => cmd('uname', '-srm')['output'],
                       'cpu' => File.read('/proc/cpuinfo')[/model name\s*:\s*(.+)/, 1], 'logical_cpus' => cmd('nproc')['output'].to_i }
}
File.write(File.join(MAN, 'provenance.json'), JSON.pretty_generate(prov) + "\n")

tsv = File.join(ROOT, 'evidence/verification/checks.tsv')
rows = File.file?(tsv) ? File.readlines(tsv, chomp: true).drop(1).map { |l| l.split("\t", 6) } : []
checks = rows.map do |step, expect, code, outcome, log, command|
  lp = File.join(ROOT, log)
  { 'step' => step, 'expect' => expect, 'exit_code' => Integer(code), 'outcome' => outcome, 'command' => command,
    'log' => log, 'log_sha256' => File.file?(lp) ? sha(lp) : nil }
end
ver = { 'schema' => 'morphic-helix/verification/1', 'generated_at' => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
        'source' => 'evidence/verification/checks.tsv (written by scripts/verify-all.sh)',
        'all_as_expected' => checks.all? { |c| c['outcome'] == 'as-expected' }, 'checks' => checks,
        'artifacts' => Dir.chdir(ROOT) { Dir['evidence/{traces,benchmarks,verification/gui}/**/*'].select { |f| File.file?(f) }.sort.to_h { |f| [f, sha(f)] } } }
File.write(File.join(MAN, 'verification.json'), JSON.pretty_generate(ver) + "\n")

list = Dir.chdir(ROOT) { Dir.glob('**/*', File::FNM_DOTMATCH).select { |f| File.file?(f) } }
list.reject! { |f| f == 'evidence/manifests/files.sha256' || f == 'evidence/verification/checks.tsv' || f == 'evidence/verification/logs/manifests.log' || f.include?('/_build/') || f.end_with?('.agdai') }
File.write(File.join(MAN, 'files.sha256'), list.sort.map { |f| "#{sha(File.join(ROOT, f))}  #{f}\n" }.join)
puts "provenance.json: #{entries.length} archive entries; verification.json: #{checks.length} checks (all_as_expected=#{ver['all_as_expected']}); files.sha256: #{list.length} files"
