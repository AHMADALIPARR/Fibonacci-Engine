# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
.PHONY: verify gui bench test screenshots manifests
verify:
	sh scripts/verify-all.sh
test:
	ruby tests/regression/test_regression.rb && ruby tests/properties/test_properties.rb && ruby tests/equivalence/test_equivalence.rb && ruby tests/integration/test_integration.rb
gui:
	ruby ruby/application/morphic_helix.rb
screenshots:
	sh scripts/gui-screenshots.sh
bench:
	ruby scripts/run_benchmarks.rb 7
manifests:
	ruby scripts/build_manifests.rb
