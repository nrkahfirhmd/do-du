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
- [x] Banner, compact, minimal, expanded per handoff.

## DD-48 · Motion + haptics — S
- [x] Motion per handoff table (no bounce; Reduce Motion stops ring and pulse). Added: Stats bars, tiles and trend animate over 0.6s when the period changes; stat numbers roll (`numericText`).
- [x] Haptics (`sensoryFeedback`, respects the system haptics switch; no-op on Mac without a Force Touch trackpad):

  | Moment | Feedback |
  |---|---|
  | Timer starts | `.start` |
  | Timer stops | `.stop` |
  | Session switched | light impact |
  | Project reaches its target | `.success` |
  | Task marked done | light impact |
  | Plan / Recap fails | `.error` |

  Nothing else buzzes: no haptics on scrolling, tab changes, sheet accept or undone tasks.

---

Added 2026-10-11 from the updated handoff (onboarding, Mac Settings window, Mac sheets). Decided: no Settings button in the menu-bar panel (app menu ⌘, only); the onboarding iCloud switch is a real opt-out (applies after relaunch when changed later); Quick Add is ⌘K in the app plus a global ⌥⌘K. The Timer widget keeps opening the app (DD-46 option A).

## DD-49 · Onboarding (iPhone + Mac) — L
- [x] Seven steps (Welcome, Project, Days, Day start, Sync and assistant, Done, Today) with the live preview card; iPhone page flow, Mac 880×600 window.
- [x] **New behaviour:** shown once per device (`hasOnboarded`), skipped when a store already exists or iCloud already has the Do-Du zone; nothing written before Go to Today; "✓ Set up" chip on Today for the first session.
- [x] **New behaviour:** iCloud opt-out (store opens without CloudKit when off); Settings → Sync switch applies next launch.
- [x] Self-check: step rules (Continue enabled, day presets, weekday mask, rest-day verdict, week summary).
- [x] Notes: the store now opens after onboarding (`Do_DuApp.container` is nil until then), so the iCloud choice decides how it opens. The widget no longer creates the store file. On iPhone only the current step's preview section shows (all of them on Done); the footer stays pinned under the keyboard, with a keyboard Done button. DEBUG: `-forceOnboarding YES -onboardingStep N`. Verified on the iPhone simulator (full flow, rest day, relaunch) and Mac test build (light/dark steps).

## DD-50 · Mac Settings window — M
- [x] `Settings` scene with General / Timer / Assistant / Data tabs per handoff (`MacSettingsView`); reopens on the last tab.
- [x] **New behaviour:** Open at login (`SMAppService`), Show in menu bar (`MenuBarExtra(isInserted:)`), idle stop 5–60m (default 10m) separate from Stop on sleep or lock, Pomodoro focus + break (a "Break's over" nudge).
- [x] Notes: Categories sit in General and the Notion/Reminders imports in Data (the handoff has no place for them). The iCloud status says On / Off / Not signed in rather than "Synced 2 minutes ago" (SwiftData doesn't expose the last sync time). iPhone keeps its single Settings form (gains the Break stepper). DEBUG: `-openSettings YES -macSettingsTab timer`. Verified each tab in a Mac test build.

## DD-51 · Mac sheets — L
- [x] Quick Add floating panel (640pt glass `NSPanel`, live five-cell preview), ⌘K in the app, **new behaviour:** global ⌥⌘K. Return adds the task and shows Tasks.
- [x] Plan My Day 620pt with Planned / To enough / Meetings strip, numbered rows with reasons (Danger when due), ±15m steppers (15m–4h), no-key state with Open Settings → Assistant. The stats strip and no-key state are on iPhone too.
- [x] Edit Task (title in its own group, Estimate stepper with "None" at 0, Delete Task) and New/Edit Project (seven day circles, Archived switch, summary line, target 15m–12h). Shared Mac sheet chrome (`MacSheet`): 22pt title, Cancel + forest primary with key hints (⌘S, ⌘↩, Esc).
- [x] Notes: the preview reads typed syntax instantly (`QuickAddSyntax`: today/tomorrow/weekday, `~30m`, `#tag`, project names; self-checked) and Foundation Models fill the gaps after a 0.45s pause; an unknown project is picked in the Project cell. Due stays a switch + date picker rather than a pop-up. No seventh mint swatch: mint means live/met in this design. DEBUG: `-macSheet quick|plan|task|project`, `-quickAddText "…"`. Verified each in a Mac test build.

## DD-52 · Mac screens — M
- [x] Today: hero bottom row (88pt record button, "Stop timer" + "Space to start or stop · ⌘⇧T anywhere", Switch task capsule; hints drop in narrow windows), radius 32, No project row with Assign….
- [x] Tasks: Open / Done / All capsules and one table per project (done · Task · Category · Due · Estimate · play, 44pt rows); clicking a title opens Edit Task.
- [x] Stats third tile (largest category's share), Assistant with Recap beside Chat, Projects in four columns of 200pt tiles with archived ones at 50%.
- [x] Notes: fixed white text on the forest project tile in dark mode (both platforms). Stats keeps the stacked list rather than the side-by-side trend/by-project panels. DEBUG: `-macSection tasks`. Verified each section in a Mac test build (dark), iPhone Tasks unchanged.
