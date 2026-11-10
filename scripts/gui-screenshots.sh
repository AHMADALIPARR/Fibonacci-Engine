#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
#
# Drives the real GTK GUI on a private Xvfb display, performs scripted mouse/keyboard actions, dumps the
# visible text morphs as JSON and captures a screenshot of each panel into evidence/verification/gui/.
#   scripts/gui-screenshots.sh
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
for t in ruby Xvfb import; do "$ROOT/scripts/require-tool.sh" "$t"; done
OUT="$ROOT/evidence/verification/gui"
mkdir -p "$OUT"
DISP=":$((90 + $$ % 9))"
Xvfb "$DISP" -screen 0 1400x900x24 -nolisten tcp >"$OUT/xvfb.log" 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null || true' EXIT INT TERM
sleep 1
export DISPLAY="$DISP"
status=0
shot() {
  name=$1; panel=$2; actions=$3
  log="$OUT/$name.log"
  ruby "$ROOT/ruby/application/morphic_helix.rb" --panel "$panel" --actions "$actions" \
       --dump-state "$OUT/$name.state.json" --quit-after 600000 >"$log" 2>&1 &
  app=$!
  i=0
  until grep -q '^state dumped' "$log" 2>/dev/null; do
    i=$((i + 1))
    if [ $i -gt 2400 ] || ! kill -0 $app 2>/dev/null; then echo "FAIL $name (see $log)"; status=1; kill $app 2>/dev/null || true; return 0; fi
    sleep 0.25
  done
  sleep 0.6
  import -display "$DISP" -window root "$OUT/$name.png"
  kill $app 2>/dev/null || true
  wait $app 2>/dev/null || true
  echo "OK $name -> evidence/verification/gui/$name.png"
}
shot 01-fibonacci fibonacci 'set:fib-depth=7,click:btn-fib-verify'
shot 02-helix helix 'click:btn-braid-forward,click:btn-braid-inverse,click:btn-helix-next,click:btn-helix-next,click:btn-helix-zoom-in'
shot 03-cbqn cbqn 'click:btn-cbqn-all'
shot 04-elf elf 'click:btn-elf-check,click:btn-elf-tm,click:btn-elf-deriv,click:btn-elf-neg'
shot 05-agda agda 'click:btn-agda-check,click:btn-agda-neg'
shot 06-turing turing 'click:btn-tm-load,click:btn-tm-step,click:btn-tm-step,click:btn-tm-run,click:btn-tm-back,click:btn-tm-verify'
shot 07-spiral spiral 'set:spiral-n=400,click:btn-spiral-verify'
shot 08-capacity capacity 'set:cap-tflops=250'
exit $status
