#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
#
# Usage: scripts/require-tool.sh TOOL...   Fails closed: prints "missing TOOL" and exits 127 for the first absent tool.
for t in "$@"; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "missing $t"
    exit 127
  fi
done
exit 0
