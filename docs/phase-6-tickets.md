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
- [ ] iPhone: pull down on Today and Tasks. Mac: toolbar Refresh (⌘R).
- [ ] Imports Notion + Reminders, reloads the calendar, saves; shows the result and sync status.

## DD-74 · Mac motion + haptics — M
- [ ] Haptics at the iPhone moments using macOS kinds (Force Touch trackpad only).
- [ ] Hover feedback, sliding sidebar selection, list insert/remove transitions, running pulse, ring fills; Reduce Motion respected.
