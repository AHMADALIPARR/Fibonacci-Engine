#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. See the LICENSE file.
#
# Closes the real GTK GUI every supported way on a private Xvfb display with a real window manager (openbox),
# and checks that the application exits and leaves no child process behind. Busy cases use a real
# `agda Everything.agda` run (agda/_build is removed first so the type-check is still running at close time).
#   scripts/gui-close-test.sh        exit 0 = every case behaved as stated; 1 = a case failed; 127 = missing tool
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/scripts/require-tool.sh" ruby agda Xvfb openbox xdotool wmctrl pgrep || exit 127
LOG="$ROOT/evidence/verification/gui-close"
mkdir -p "$LOG"
DISP=":$((40 + $$ % 40))"
Xvfb "$DISP" -screen 0 1600x1000x24 -nolisten tcp >"$LOG/xvfb.log" 2>&1 &
XPID=$!
sleep 1
export DISPLAY="$DISP"
openbox >"$LOG/openbox.log" 2>&1 &
WPID=$!
sleep 1
trap 'kill $WPID $XPID 2>/dev/null' EXIT
fail=0
APP=""
WID=""

ms() { date +%s%3N; }
start_app() {
  ruby "$ROOT/ruby/application/morphic_helix.rb" >"$LOG/$1.app.log" 2>&1 &
  APP=$!
  WID=""
  i=0
  while [ -z "$WID" ] && [ $i -lt 100 ]; do
    sleep 0.3; i=$((i + 1))
    WID=$(xdotool search --onlyvisible --name '^MORPHIC HELIX$' 2>/dev/null | head -1)
  done
  [ -n "$WID" ] || { echo "FAIL $1: window never appeared"; fail=1; }
  sleep 1
}
# wait_exit SECONDS: 0 if the app exited in time
wait_exit() {
  i=0
  while kill -0 "$APP" 2>/dev/null; do
    i=$((i + 1)); [ $i -gt $(($1 * 20)) ] && return 1; sleep 0.05
  done
  return 0
}
mine() { pgrep -f "$ROOT/agda|agda Everything.agda|twelf-server|elf_backend.rb|cli.bqn|oracle.js" 2>/dev/null | tr '\n' ' '; }
expect_exit() { # case-name seconds t0
  if wait_exit "$2"; then echo "OK   $1: exited $(( $(ms) - $3 )) ms after the close request"
  else echo "FAIL $1: still running $2 s after the close request"; fail=1; kill -9 "$APP" 2>/dev/null; fi
}
expect_no_children() {
  sleep 0.5
  left=$(mine)
  if [ -z "$left" ]; then echo "OK   $1: no child process left"; else echo "FAIL $1: child processes left: $left"; fail=1; pkill -9 -f 'agda Everything.agda' 2>/dev/null; fi
}
click() { xdotool mousemove --window "$WID" "$1" "$2" click 1; }
agda_busy() { # opens the Agda tab and starts the type-check; 0 if agda is running afterwards
  rm -rf "$ROOT/agda/_build"
  click 766 21; sleep 0.3
  click 170 445; sleep 0.5
  pgrep -f 'agda Everything.agda' >/dev/null
}

start_app wm-close-idle; t0=$(ms); wmctrl -i -c "$WID"; expect_exit wm-close-idle 3 "$t0"
start_app escape; t0=$(ms); xdotool windowactivate --sync "$WID" key Escape; expect_exit escape 3 "$t0"
start_app ctrl-q; t0=$(ms); xdotool windowactivate --sync "$WID" key ctrl+q; expect_exit ctrl-q 3 "$t0"

start_app ctrl-w
n=0; while [ $n -lt 7 ]; do xdotool windowactivate --sync "$WID" key ctrl+w; sleep 0.3; n=$((n + 1)); done
closed=$(grep -c '^panel closed: ' "$LOG/ctrl-w.app.log")
if kill -0 "$APP" 2>/dev/null && [ "$closed" -eq 7 ]; then echo "OK   ctrl-w: 7 of 8 panels closed, window still open"
else echo "FAIL ctrl-w: $closed panels reported closed, app alive: $(kill -0 "$APP" 2>/dev/null && echo yes || echo no)"; fail=1; fi
t0=$(ms); xdotool windowactivate --sync "$WID" key ctrl+w; expect_exit ctrl-w-last-panel 3 "$t0"

start_app panel-close-busy
if agda_busy; then
  t0=$(ms); click 849 21   # the × on the Agda tab
  sleep 0.3
  if kill -0 "$APP" 2>/dev/null && grep -q '^panel closed: agda' "$LOG/panel-close-busy.app.log" && ! pgrep -f 'agda Everything.agda' >/dev/null; then
    echo "OK   panel-close-busy: Agda panel closed and its agda process terminated within $(( $(ms) - t0 )) ms, window still open"
  else echo "FAIL panel-close-busy: panel-closed line: $(grep -c '^panel closed: agda' "$LOG/panel-close-busy.app.log"), agda still running: $(pgrep -f 'agda Everything.agda' >/dev/null && echo yes || echo no)"; fail=1; fi
  expect_no_children panel-close-busy
else echo "FAIL panel-close-busy: agda was not running when the panel was closed"; fail=1; fi
t0=$(ms); wmctrl -i -c "$WID"; expect_exit panel-close-busy-then-wm-close 3 "$t0"

start_app wm-close-busy
if agda_busy; then
  t0=$(ms); wmctrl -i -c "$WID"; expect_exit wm-close-busy 1 "$t0"; expect_no_children wm-close-busy
else echo "FAIL wm-close-busy: agda was not running at close time"; fail=1; kill "$APP"; fi

start_app sigterm-busy
if agda_busy; then
  t0=$(ms); kill -TERM "$APP"; expect_exit sigterm-busy 1 "$t0"; expect_no_children sigterm-busy
else echo "FAIL sigterm-busy: agda was not running at SIGTERM"; fail=1; kill "$APP"; fi

exit $fail
