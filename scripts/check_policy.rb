# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
# frozen_string_literal: true

# Repository policy check (exit 1 on any violation):
#  * every code file carries both licence header lines in its native comment syntax
#    (exempt: the byte-exact pristine originals under source/original-archive/pristine/);
#  * LICENSE is the official GNU AGPLv3 text (sha256 of https://www.gnu.org/licenses/agpl-3.0.txt as downloaded);
#  * no other licence identifiers, no CI besides .github/workflows/pages.yml, no tar archives;
#  * no Agda escape hatches (postulate, holes) and every Agda module is --safe;
#  * no Python, TypeScript or React sources in the product.
require 'digest'
ROOT = File.expand_path('..', __dir__)
AGPL_SHA = '0d96a4ff68ad6d4b6f1f30f713b18d5184912ba8dd389f86aa7710db079abcb0'
L1 = 'SPDX-License-Identifier: AGPL-3.0-only'
L2 = 'This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.'
COMMENT = { '.rb' => '#', '.bqn' => '#', '.sh' => '#', '.js' => '//', '.als' => '//', '.elf' => '%', '.cfg' => '%',
            '.agda' => '--', '.agda-lib' => '--', '.yml' => '#', '.yaml' => '#', 'Makefile' => '#' }.freeze
SKIP_DIRS = %r{\A(evidence|agda/_build|tests/properties/agda-negative/_build|source/original-archive/pristine)/}

errors = []
files = Dir.chdir(ROOT) { Dir.glob('**/*', File::FNM_DOTMATCH).select { |f| File.file?(f) } }.sort
checked = 0
files.each do |f|
  next if f.match?(SKIP_DIRS) || f.end_with?('.agdai')

  key = File.basename(f) == 'Makefile' ? 'Makefile' : File.extname(f)
  errors << "#{f}: product source in a forbidden language" if %w[.py .ts .tsx .jsx].include?(key)
  errors << "#{f}: tar archive" if f.match?(/\.tar(\.gz)?\z|\.tgz\z/)
  next unless (c = COMMENT[key])

  checked += 1
  head = File.read(File.join(ROOT, f)).lines.first(6).map(&:chomp)
  head.shift if head.first&.start_with?('#!')
  errors << "#{f}: missing SPDX line" unless head[0] == "#{c} #{L1}"
  errors << "#{f}: missing AGPL notice line" unless head[1] == "#{c} #{L2}"
end
errors << 'LICENSE is not the official AGPLv3 text' unless Digest::SHA256.file(File.join(ROOT, 'LICENSE')).hexdigest == AGPL_SHA
pages_workflow = '.github/workflows/pages.yml'
if File.directory?(File.join(ROOT, '.github'))
  extra = Dir.glob(File.join(ROOT, '.github', '**', '*'), File::FNM_DOTMATCH).select { |f| File.file?(f) }.map { |f| f.delete_prefix("#{ROOT}/") }.reject { |f| f == pages_workflow }.sort
  errors << ".github/ has files other than the Pages workflow: #{extra.join(', ')}" unless extra.empty?
end
errors << 'CI workflow files present' unless Dir.glob(File.join(ROOT, '**/{.gitlab-ci.yml,.travis.yml,azure-pipelines.yml,Jenkinsfile}')).empty?
Dir.chdir(ROOT) do
  (Dir['**/*.{rb,bqn,sh,js,als,elf,agda,cfg,yml,yaml}'] + ['Makefile']).each do |f|
    next if f.match?(SKIP_DIRS) || f == 'scripts/check_policy.rb' || !File.file?(f)

    t = File.read(f)
    errors << "#{f}: foreign licence identifier" if t.match?(/SPDX-License-Identifier:(?!\s*AGPL-3\.0-only)/) || t.match?(/\bMIT License\b|GPL-3\.0-or-later|Apache-2\.0/)
  end
  Dir['agda/**/*.agda', 'tests/properties/agda-negative/*.agda'].each do |f|
    next if f.include?('_build')

    t = File.read(f)
    errors << "#{f}: not --safe" unless t.include?('OPTIONS --safe')
    errors << "#{f}: contains a hole" if t.include?('{!')
    errors << "#{f}: contains postulate" if t.match?(/^\s*postulate\b/) && !f.end_with?('PostulateRejected.agda')
  end
end
puts "checked headers on #{checked} code files"
if errors.empty?
  puts 'policy OK'
else
  puts errors
  exit 1
end
