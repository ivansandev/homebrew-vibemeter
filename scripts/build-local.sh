#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

xcodegen generate
xcodebuild \
  -project VibeMeter.xcodeproj \
  -scheme VibeMeter \
  -configuration Debug \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "Built $ROOT/DerivedData/Build/Products/Debug/VibeMeter.app"
