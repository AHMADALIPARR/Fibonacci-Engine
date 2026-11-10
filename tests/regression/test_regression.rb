# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Regression suite.
#  * golden/original_main.stdout is the stdout of `node fibonacci_braid.js` on the PRISTINE original, recorded
#    with Node v24.22.1 on 2026-11-10 (see evidence/manifests/provenance.json). Both the pristine and the
#    licence-headered copy must keep producing it byte for byte.
#  * the archive files must keep their recorded SHA-256 values.
#  * each original code file has exactly ONE headered copy, which differs from the pristine file only by the
#    two prepended licence lines:
#      fibonacci_braid.js   -> source/original-archive/fibonacci_braid/fibonacci_braid.js
#      braid_invariant.als  -> alloy/specifications/braid_invariant.als (the copy Alloy runs)
#    README.md is documentation, not code; it exists only as the pristine file.
require 'minitest/autorun'
require 'digest'
require 'open3'
require_relative '../../ruby/adapters/process_runner'

class RegressionTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  PRISTINE = File.join(ROOT, 'source/original-archive/pristine/fibonacci_braid')
  HEADERED = {
    'fibonacci_braid.js' => File.join(ROOT, 'source/original-archive/fibonacci_braid/fibonacci_braid.js'),
    'braid_invariant.als' => File.join(ROOT, 'alloy/specifications/braid_invariant.als')
  }.freeze
  HASHES = {
    'README.md' => '1bb135f8ad894e376256b412da8b74854007ce0bcfdb67228068edf11199327c',
    'braid_invariant.als' => 'ad17b3bcbfa37325cb77564e0a5eeb310876efa892136a184c930a1edfb929fb',
    'fibonacci_braid.js' => 'f12cebedac499267d2cc7096dae429914f2b801898d66a055a2d9f97bdbd24f2'
  }.freeze
  HEADER = ['// SPDX-License-Identifier: AGPL-3.0-only',
            '// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.'].freeze

  def node = MorphicHelix::ProcessRunner.which('node', env_var: 'MH_NODE')

  def test_pristine_hashes
    HASHES.each { |f, h| assert_equal h, Digest::SHA256.file(File.join(PRISTINE, f)).hexdigest, f }
  end

  def test_headered_copies_differ_only_by_header
    HEADERED.each do |f, copy|
      lines = File.read(copy).lines
      assert_equal HEADER, lines.first(2).map(&:chomp), f
      assert_equal File.read(File.join(PRISTINE, f)), lines.drop(2).join, f
    end
  end

  def test_golden_main_output
    golden = File.read(File.join(__dir__, 'golden', 'original_main.stdout'))
    [File.join(PRISTINE, 'fibonacci_braid.js'), HEADERED['fibonacci_braid.js']].each do |js|
      out, err, st = Open3.capture3(node, js)
      assert st.success?, err
      assert_equal golden, out, js
    end
  end

  # No byte-identical second copy of an original may exist outside pristine/ (the zip itself excepted), and
  # each headered copy is the only one for its file.
  def test_single_copy_of_each_original
    files = Dir.chdir(ROOT) { Dir.glob('**/*', File::FNM_DOTMATCH).select { |f| File.file?(f) } }
    files.reject! { |f| f.start_with?('source/original-archive/pristine/') || f.include?('/_build/') }
    dupes = files.select { |f| HASHES.value?(Digest::SHA256.file(File.join(ROOT, f)).hexdigest) }
    assert_equal [], dupes, 'byte-identical copies of original files outside pristine/'
    headered = HEADERED.to_h { |f, copy| [f, File.read(copy)] }
    others = files.select { |f| headered.value?(File.read(File.join(ROOT, f), mode: 'rb').force_encoding('UTF-8')) }
    assert_equal HEADERED.values.map { |p| p.delete_prefix("#{ROOT}/") }.sort, others.sort, 'headered copies'
  end
end
