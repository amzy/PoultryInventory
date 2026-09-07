#!/bin/bash
set -euo pipefail
if [ ! -d "ios/Runner" ]; then
  flutter create --platforms=ios .
fi
flutter pub get
