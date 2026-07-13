#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

MARKER="/tmp/vibemeter-live-tests-enabled-$UID"
touch "$MARKER"
trap 'rm -f "$MARKER"' EXIT

xcodebuild \
  -project VibeMeter.xcodeproj \
  -scheme VibeMeter \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  test
