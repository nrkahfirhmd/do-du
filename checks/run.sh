#!/bin/sh
# Compiles app core files + checks/main.swift into a throwaway binary and runs it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Do-Du/Do-Du"
OUT="${TMPDIR:-/tmp}/dodu-checks"
xcrun swiftc -default-isolation MainActor -o "$OUT" \
  "$SRC/Models.swift" \
  "$ROOT/checks/main.swift"
"$OUT"
