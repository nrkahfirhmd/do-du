#!/bin/sh
# Compiles app core files + checks/main.swift into a throwaway binary and runs it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Do-Du/Do-Du"
OUT="${TMPDIR:-/tmp}/dodu-checks"
xcrun swiftc -default-isolation MainActor -o "$OUT" \
  "$SRC/Core/Models.swift" "$SRC/DesignSystem/DesignSystem.swift" "$SRC/Core/SessionTimeline.swift" "$SRC/Core/DayMath.swift" "$SRC/Core/Stats.swift" "$SRC/Core/TimerService.swift" "$SRC/Core/Keychain.swift" "$SRC/Services/AI/ClaudeClient.swift" "$SRC/Services/AI/AISnapshot.swift" "$SRC/Services/AI/QuickAddParser.swift" "$SRC/Services/AI/DayPlan.swift" "$SRC/Services/AI/ChatTools.swift" "$SRC/Core/CSVExport.swift" "$SRC/Services/System/IdleStop.swift" "$SRC/Core/SharedStore.swift" "$SRC/Services/Integrations/TaskSource.swift" "$SRC/Services/Integrations/NotionClient.swift" "$SRC/Services/Integrations/RemindersSource.swift" "$SRC/Services/Integrations/DoDuIntents.swift" "$SRC/Features/Onboarding/Onboarding.swift" "$SRC/Services/System/SyncMonitor.swift" \
  "$ROOT/checks/main.swift"
"$OUT"
