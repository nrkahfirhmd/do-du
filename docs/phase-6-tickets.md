# Do-Du — Phase 6 Tickets (3rd iteration)

Source: owner's 3rd-iteration feedback, 2026-10-11. Rules still come from [AGENTS.md](AGENTS.md).

Decided 2026-10-11: deleting a session is permanent, with Undo. Manual refresh can't force a CloudKit pull (no API); it imports, reloads the calendar and saves so pending changes upload.

Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days.

---

## DD-70 · Timer project menu lists every project — S
- [x] The timer card's project menu shows all non-archived projects, not just today's; the verdict still counts only today's.

## DD-71 · Menu bar setting stays on — S
- [x] Only a user removal turns "Show in menu bar" off; the removal while onboarding runs no longer does.

## DD-72 · Delete sessions — M
- [x] Today lists today's sessions (iPhone + Mac); delete from the context menu (long-press / right-click) or the trash on hover (Mac), with an inline Undo for 6 s.
- [x] A running session must be stopped first.

## DD-73 · Manual refresh — M
- [x] iPhone: pull down on Today and Tasks. Mac: toolbar Refresh (⌘R).
- [x] Imports Notion + Reminders, reloads the calendar, saves; a banner shows the result (imports, errors, last iCloud sync).

## DD-74 · Mac motion + haptics — M
- [x] Haptics at the iPhone moments via `SensoryFeedback.dd*` (Mac maps to `.levelChange` / `.alignment`, the only kinds macOS plays; Force Touch trackpad only).
- [x] Hover lift on buttons, tiles and the record button; row highlight in tables and sessions; section crossfade; task/session insert/remove transitions; running pulse and ring fills (already there). Reduce Motion turns off the lift. Sidebar selection stays the system's.
- [ ] Owner: feel the haptics on a Force Touch trackpad.
