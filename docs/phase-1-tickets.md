# Do-Du — Phase 1 Tickets (Core Loop)

Source spec: [AGENTS.md](AGENTS.md) — requirements R1–R6.
Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days. Work top to bottom; each ticket lists blockers.

**Phase done when:** used daily for 1 week on Mac + iPhone with no data issues.

---

## DD-01 · Data models — M
**Req:** R1, R2, R3 · **Blocked by:** —

Replace template `Item.swift` with SwiftData models `Project`, `Category`, `Task`, `TimeEntry` per spec data model.

- [x] Models are CloudKit-compatible from day one: every property optional or has default, all relationships optional with inverses, no `@Attribute(.unique)`.
- [x] `TaskItem` includes `externalSource?` / `externalID?` (Phase 3 insurance).
- [x] `TimeEntry.end == nil` means running.
- [x] Delete rules: project cascades tasks + entries; category nullifies. (Confirm dialog lives in DD-03.)
- [x] `Item.swift` and template `ContentView` list removed.
- [x] Self-check (`checks/run.sh`): create project → task → entry, fetch back, cascade delete.

## DD-02 · Day-boundary & stats math — M
**Req:** R4, R5 · **Blocked by:** DD-01

Pure functions (no UI) that every view reuses.

- [x] `minutes(for project, on day)` and `minutes(for category, in range)`.
- [x] Entries crossing local midnight split across days.
- [x] Running entry counts up to `now`.
- [x] `verdict(for day) -> .notYet | .enough | .restDay` (rest day = no project active that weekday).
- [x] Tests: midnight split, running entry, rest day, target exactly met, archived project excluded.

## DD-03 · Projects & categories CRUD (macOS) — M
**Req:** R1 · **Blocked by:** DD-01

- [x] Projects screen lists active projects (sidebar tab on Mac); create/edit sheet: name, color, daily target (h:mm), active weekdays.
- [x] Archive / unarchive; archived section collapsed.
- [x] Categories managed in Settings: name, color.
- [x] Validation: name required, target ≥ 0.

## DD-04 · Tasks CRUD & list (macOS) — M
**Req:** R2 · **Blocked by:** DD-03

- [ ] Task list for selected project; "All" view grouped by project.
- [ ] Create/edit: title, project (required), category, notes, due date, estimate.
- [ ] Filters: category, open/done, due today.
- [ ] Mark done / reopen (sets/clears `completedAt`).
- [ ] Empty states for no projects / no tasks.

## DD-05 · Timer service — L
**Req:** R3 · **Blocked by:** DD-01

One place that owns start/stop. Views never write `TimeEntry` directly.

- [ ] `start(task)`: stops any running entry at same instant, creates new one.
- [ ] `stop()`: sets `end = now`.
- [ ] Elapsed always `now - start` from stored data; correct after quit, sleep, crash.
- [ ] On launch: if >1 running entry found (e.g. sync), keep latest start, stop others at that start time.
- [ ] Tests: switch tasks, relaunch with running entry, two running entries resolved.

## DD-06 · Timer UI + menu bar (macOS) — M
**Req:** R3 · **Blocked by:** DD-04, DD-05

- [ ] Play/stop button on every task row (1 click).
- [ ] Running task highlighted in list.
- [ ] `MenuBarExtra`: running task name + elapsed, stop button, quick-start from recent tasks.
- [ ] Keyboard shortcut to stop current timer.

## DD-07 · Manual time entries — M
**Req:** R3 · **Blocked by:** DD-05

- [ ] Per-task entry list: add, edit, delete.
- [ ] Validation: `end > start`; reject overlap with other entries, show which entry conflicts.
- [ ] Cannot set `end` on running entry into the future.

## DD-08 · Long-run warning — S
**Req:** R3 · **Blocked by:** DD-05

- [ ] Local notification when timer exceeds threshold (default 3h, Settings).
- [ ] Notification actions: "Stop now", "Stop at…" (opens edit), "Keep going".
- [ ] Rescheduled on start, cancelled on stop.

## DD-09 · Today view — M
**Req:** R4 · **Blocked by:** DD-02, DD-06

- [ ] Default screen. Per active-today project: tracked / target + progress bar.
- [ ] Overall banner: *Not yet* (time left) / *Enough* / *Rest day*.
- [ ] Updates live while timer runs.
- [ ] Tasks due today listed with start buttons.

## DD-10 · Statistics view — M
**Req:** R5 · **Blocked by:** DD-02

- [ ] Range picker: day / week / month, prev/next.
- [ ] Time by project and by category (Swift Charts bar).
- [ ] "Enough" days count in range.
- [ ] Per-project daily trend chart.

## DD-11 · iOS target — L
**Req:** R6 · **Blocked by:** DD-09, DD-10, DD-07

- [ ] Add iOS app target sharing models, timer service, stats code (shared group, not copies).
- [ ] Min iOS = 27 (assumed to match macOS 27 — confirm, spec Open Question 4).
- [ ] iPhone layouts: Today, Projects/Tasks, Stats, Settings tabs.
- [ ] Timer start/stop ≤ 2 taps from Today and task list.
- [ ] Long-run notification works on iOS.

## DD-12 · CloudKit sync — M
**Req:** R6 · **Blocked by:** DD-01 (can start any time after), needed before DD-13

- [ ] iCloud + CloudKit capability, private container, both targets.
- [ ] `ModelContainer` configured with CloudKit.
- [ ] Sync on launch + background push.
- [ ] App works offline; syncs when back online.
- [ ] Clear message if iCloud signed out.

## DD-13 · Cross-device timer test pass — M
**Req:** R6 · **Blocked by:** DD-11, DD-12

Manual test script, written as checklist in this file or `docs/`.

- [ ] Start on Mac → iPhone shows running, same elapsed (±few s).
- [ ] Start on Mac, stop on iPhone → one entry, correct end.
- [ ] Both offline, start different tasks, reconnect → later start wins, earlier stopped at later start (DD-05 rule).
- [ ] Edit entry on one device → reflected on other.
- [ ] Delete project on one device → gone on other, no orphan entries.

---

## Order & parallelism

1. **DD-01** first.
2. Then in parallel: **DD-02**, **DD-03 → DD-04**, **DD-05 → DD-07 / DD-08**, **DD-12** spike.
3. **DD-06** (needs DD-04 + DD-05), **DD-10** (needs DD-02).
4. **DD-09** (needs DD-02 + DD-06).
5. **DD-11** (needs DD-07, DD-09, DD-10).
6. **DD-13** last (needs DD-11 + DD-12).

**Rough total:** ~14–17 days of focused work.

**Do early:** DD-12 spike right after DD-01 — CloudKit model rules break late if ignored (spec risk #1).
