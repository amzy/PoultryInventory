#!/bin/bash
set -euo pipefail

flutter config --enable-web
flutter pub get
flutter build web --release --base-href /
cp web/CNAME build/web/CNAME

echo "Web build complete: build/web"
echo "Base href: $(grep -o '<base href="[^"]*"' build/web/index.html | head -1)"
echo "Bootstrap: $(test -f build/web/flutter_bootstrap.js && echo OK || echo MISSING)"
echo "CNAME: $(cat build/web/CNAME)"
