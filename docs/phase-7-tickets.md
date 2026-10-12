# Do-Du — Phase 7 Tickets (4th iteration)

Source: owner's 4th-iteration feedback, 2026-10-12. Rules still come from [AGENTS.md](AGENTS.md).

Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days.

---

## DD-80 · Single-screen onboarding — M
- [x] One screen: iCloud toggle + Claude key field; Continue saves both, Skip finishes with defaults.
- [x] No starter project, days or day-start step; first project is created in Projects, day start stays in Settings.
- [x] Store still opens only after onboarding; the iCloud-has-data skip is unchanged.
- [ ] Owner: fresh-install check (Continue and Skip) with real iCloud data.

## DD-81 · Mac refresh shows a sync error while iPhone syncs — S
- [x] Diagnosis only, no sync-logic change: refresh can't force a CloudKit pull, so its banner reports the last sync result (logged decision). A Mac-only `CKError 2` means this Mac's push is rejected while the iPhone's succeeds.
- [x] Banner labels the sync tail (`iCloud: …`) so the error isn't mistaken for an import result.
- [ ] Owner: deploy the CloudKit schema to Production; run the same build source (both TestFlight or both Xcode, team `84L3QCBHMU`) on both devices; same iCloud account; relaunch after toggling Sync. See [sync-test-plan.md](sync-test-plan.md).

## DD-82 · Timer stops on sleep only — S
- [x] Mac stops the running timer on system sleep (`willSleep`) only; screensaver, display sleep and lock leave it running.
- [x] Settings toggle renamed to "Stop on sleep"; idle stop still backdates to last activity.
- [ ] Owner: check sleep vs. screensaver on a signed Mac build.

## DD-83 · Optional screensaver and lock stops — S
- [x] Separate "Stop on screensaver" and "Stop on lock" switches, both off by default; sleep keeps its switch.
- [x] Each stop fires at that moment with its own message; idle stop still backdates.
- [ ] Owner: try the combinations on a signed Mac build.
