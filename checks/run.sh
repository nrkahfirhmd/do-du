#!/bin/sh
# Compiles app core files + checks/main.swift into a throwaway binary and runs it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Do-Du/Do-Du"
OUT="${TMPDIR:-/tmp}/dodu-checks"
xcrun swiftc -default-isolation MainActor -o "$OUT" \
  "$SRC/Models.swift" "$SRC/DayMath.swift" "$SRC/Stats.swift" "$SRC/TimerService.swift" "$SRC/Keychain.swift" "$SRC/ClaudeClient.swift" "$SRC/AISnapshot.swift" "$SRC/QuickAddParser.swift" "$SRC/DayPlan.swift" "$SRC/ChatTools.swift" "$SRC/CSVExport.swift" "$SRC/IdleStop.swift" "$SRC/SharedStore.swift" "$SRC/TaskSource.swift" "$SRC/NotionClient.swift" "$SRC/DoDuIntents.swift" \
  "$ROOT/checks/main.swift"
"$OUT"
