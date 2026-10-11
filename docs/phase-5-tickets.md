# Do-Du — Phase 5 Tickets (2nd iteration)

Source: owner's 2nd-iteration feedback, 2026-10-11. Rules still come from [AGENTS.md](AGENTS.md).

Decided 2026-10-11: no Firebase; diagnose CloudKit first (Mac and iPhone showed different projects). Notion/Reminders import runs automatically.

Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days.

---

## DD-60 · iCloud sync status — S
- [x] `SyncMonitor` records the last CloudKit event (success or error) from launch.
- [x] Settings (iPhone + Mac) show "Synced …" or the error; Today shows a line while sync fails.
- [ ] Owner: deploy the CloudKit schema to Production and run TestFlight builds on both devices.

## DD-61 · Tasks empty state (Mac) — S
- [ ] Content fills the window; the empty state sits in the page, not over a narrow column.

## DD-62 · Chat input field — S
- [ ] "Ask Do-Du" field is one pill (no inner border); send button lines up with it.

## DD-63 · Timer card project chip — S
- [ ] Project chip sits flush right in the card header.

## DD-64 · Dismiss keyboard on iPhone — S
- [ ] Chat and editor sheets dismiss the keyboard on scroll and with a Done button.

## DD-65 · Styled due date picker — M
- [ ] Due date chip with quick picks (Today, Tomorrow, Next week, Clear) and an app-tinted calendar.

## DD-66 · Automatic imports — M
- [ ] Notion and Reminders import on app activation and every 15 min; linked tasks refresh, new items with a matching project are added, unmatched stay for the import sheet.
- [ ] Today's calendar events refresh when the calendar changes.
- [ ] Settings switch to turn automatic import off.
