#!/bin/sh
set -eu
mkdir -p web
URL="https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3_flutter_libs-0.5.42/sqlite3.wasm"
echo "Downloading SQLite WASM runtime..."
curl -L --fail --retry 3 "$URL" -o web/sqlite3.wasm
echo "SQLite WASM runtime installed at web/sqlite3.wasm"
