#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
#
# Usage: scripts/elf-check.sh [EXTRA.elf]
# Loads elf/sources.cfg into twelf-server (and then EXTRA.elf, if given). Prints the transcript.
# Exit 0 if Twelf reports %% OK %% with no %% ABORT %%, exit 1 otherwise, 127 if twelf-server is missing.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/require-tool.sh" twelf-server
extra=""
if [ $# -gt 0 ]; then extra="loadFile $(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; fi
out=$(cd "$ROOT/elf" && printf 'set chatter 3\nConfig.read sources.cfg\nConfig.load\n%s\nquit\n' "$extra" | twelf-server 2>&1)
printf '%s\n' "$out"
case "$out" in *'%% ABORT %%'*) exit 1 ;; esac
case "$out" in *'%% OK %%'*) exit 0 ;; esac
exit 1
