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
- [x] Tab bar styling: native Liquid Glass tab bar tinted forest (system pill, not a solid forest capsule — system bar can't be restyled; handoff says keep native controls). Settings gear on Today.
- [x] **New behaviour:** timer accessory via native `tabViewBottomAccessory` on every tab except Today (tap → Today, Stop). Verified in simulator.

## DD-43 · iPhone tabs, sheets, menus — L
- [x] Tasks: coloured project capsule headers, restyled TaskRow + play button.
- [x] Assistant (Recap / Chat bubbles), Stats (tiles + bars), Projects (colour tiles + New project tile).
- [x] Shared sheet layout: native glass toolbar (ink Cancel, forest Save/Accept/Import/Next via `ddPrimary()`), inline title, surface groups on white (`ddForm()` / `ddRows()`), mint switches (`MintSwitch`). Menus stay native.
- [x] Verified in iOS simulator: Tasks, Projects, Stats, Recap, Chat, task editor, Settings.

## DD-44 · Mac window — L
- [x] NavigationSplitView sidebar (sections, projects with today %, mini timer card), toolbar (Quick Add ⌘K, Plan My Day).
- [x] Today two-column (128pt clock hero, verdict card, tiles, Sessions today table, No project row); Tasks tables; Stats; Assistant; Projects grid.
- [x] Space starts/stops the timer in the window.
- [x] Notes: native title + date subtitle instead of a custom toolbar title; Tasks, Stats, Assistant and Projects reuse the restyled shared views (Projects grid adapts to 4+ columns); Tasks keeps the list layout rather than a multi-column table. Space uses a key-press handler on Today so it never steals spaces from text fields. Verified light + dark via a sandboxed test build.

## DD-45 · Mac menu-bar panel + global hotkey — M
- [x] Panel restyle (hero card, verdict line, Recent, footer). Menu-bar icon stays a static symbol.
- [x] **New behaviour:** ⌘⇧T global hotkey (Carbon `RegisterEventHotKey`, no Accessibility permission) toggles the timer from any app; Shortcuts actions stay.
- [x] Settings toggle (Mac, on by default). Registration verified (`noErr`) in a sandboxed build; the key press itself and the panel visuals still need a check on your Mac (keystrokes need Accessibility, opening the menu-bar panel needs a click).

## DD-46 · Widgets — L
- [x] Restyle Today small/medium, add large; small Timer widget; Lock Screen circular / rectangular / inline.
- [x] **New behaviour:** widget start/stop opens the app via `dodu://timer/toggle` (decision: option A).

## DD-47 · Live Activity + Dynamic Island — M
- [ ] Banner, compact, minimal, expanded per handoff.
