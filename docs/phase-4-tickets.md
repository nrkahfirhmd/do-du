# Do-Du — Phase 4 Tickets (Redesign)

Source: design handoff in `docs/design_handoff_dodu_app/` (git-ignored; README has every token). Behaviour, data and rules still come from [AGENTS.md](AGENTS.md); this phase changes visuals and layout only, plus the items marked **new behaviour**.

Decided 2026-10-11: dark mode too (adapted from the light tokens); keep Shortcuts and add a real ⌘⇧T global hotkey on Mac; widget start/stop opens the app (no widget-process writes).

Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days. Verify each screen in the simulator against the prototype.

---

## DD-40 · Design foundation + dark mode — M
- [x] `DesignSystem.swift`: colour roles (light from handoff, dark adapted), rounded type scale, radii, motion, Reduce Motion handling.
- [x] Project palette: map existing `colorName` values onto forest, sage, `#5E9C8C`, `#9CC4B6`, `#2F6B5D`, `#8B93A7` (no data change).
- [x] Shared pieces: StatusChip, ProjectChip, ProgressRing, StatTile, SessionStripView, RecordButton (breathing ring), DDIconButton, highlight tag. (Sheet chrome moves to DD-43.)
- [x] Self-check: palette mapping, session-strip layout math.

## DD-41 · iPhone Today record screen — L
- [x] Timer hero (idle / recording): chips, title, 84pt clock, three stats, session strip, record button flanked by Switch + Plan.
- [x] **New behaviour:** Switch menu (switch task or project while running).
- [x] Verdict strip with ring + highlighted sentence; two-column project tiles (mint when met); No project row; Due today.
- [x] Verified in iOS simulator: recording + idle, light + dark, Switch menu (idle picks the quick-session project; running switches). Existing Plan, Schedule and iCloud notice kept below the tiles.

## DD-42 · iPhone shell — M
- [ ] Tab bar styling (forest selection); Settings gear on Today.
- [ ] **New behaviour:** timer accessory above the tab bar on every tab except Today (tap → Today, Stop).

## DD-43 · iPhone tabs, sheets, menus — L
- [ ] Tasks: coloured project capsule headers, restyled TaskRow + play button.
- [ ] Assistant (Recap / Chat bubbles), Stats (tiles + bars), Projects (colour tiles + New project tile).
- [ ] Shared sheet layout (Cancel/Save capsules), menus.

## DD-44 · Mac window — L
- [ ] NavigationSplitView sidebar (sections, projects with today %, mini timer card), toolbar (Quick Add ⌘K, Plan My Day).
- [ ] Today two-column (128pt clock hero, verdict card, tiles, Sessions today table, No project row); Tasks tables; Stats; Assistant; Projects grid.
- [ ] Space starts/stops the timer in the window.

## DD-45 · Mac menu-bar panel + global hotkey — M
- [ ] Panel restyle (hero card, verdict line, Recent, footer). Menu-bar icon stays a static symbol.
- [ ] **New behaviour:** ⌘⇧T global hotkey (Carbon `RegisterEventHotKey`, no Accessibility permission) toggles the timer from any app; Shortcuts actions stay.

## DD-46 · Widgets — L
- [ ] Restyle Today small/medium, add large; small Timer widget; Lock Screen circular / rectangular / inline.
- [ ] **New behaviour:** widget start/stop opens the app via `dodu://timer/toggle` (decision: option A).

## DD-47 · Live Activity + Dynamic Island — M
- [ ] Banner, compact, minimal, expanded per handoff.
