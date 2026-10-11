# Do-Du — Product Spec

> Personal to-do list + work timer. Purpose: answer one question at end of every day — **"Did I do enough today?"** — with data, not guilt.

**Owner:** Kahfi R · **Version:** 1.0 (build 1) · **Status:** Phases 1–4 done, Phase 5 (2nd iteration) code complete · **Last updated:** 2026-10-11

---

## Current Version

**1.0 (build 1)** — `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Do-Du.xcodeproj`. Not released; personal builds from `main`.

| Area | State | Built | Verified | Still to check (needs you / devices) |
|---|---|---|---|---|
| **Phase 1 — Core loop** (DD-01…14) | Done | Projects, categories, tasks, timer + quick timer, manual entries, long-run warning, Today verdict, Stats, Mac menu bar, iPhone, CloudKit sync | `checks/run.sh`; iPhone simulator | iCloud container in Xcode; cross-device sync test ([sync-test-plan.md](sync-test-plan.md)) |
| **Phase 2 — AI assistant** (DD-20…30) | Done | Quick Add (on-device), Recap, Plan my day, Chat, day-start hour, CSV export, Pomodoro, widgets + Live Activity, Mac idle/sleep stop | Quick Add live in simulator; Claude paths offline + no-key UI | Claude features with your API key; widget + Live Activity on device |
| **Phase 3 — Integrations** (DD-31…34) | Done | Notion import, Apple Calendar (read-only), Siri/Shortcuts, Reminders import | Parsing/mapping in `checks/run.sh`; Reminders permission + sheet in simulator | Live Notion import; Calendar access; Siri phrases; real reminders |
| **Phase 4 — Redesign** (DD-40…52, [tickets](phase-4-tickets.md)) | Done (DD-40…52) | Design tokens + light/dark, timer-first Today, tab bar + timer accessory, restyled tabs and sheets, Mac window + menu-bar panel, ⌘⇧T hotkey, widgets (Today S/M/L, Timer, Lock Screen), Live Activity + Dynamic Island, app icon, motion + haptics, onboarding, Mac Settings window, Mac sheets + Quick Add panel (⌥⌘K), Mac Tasks table | iPhone simulator light/dark; medium widget toggle; Dynamic Island compact/expanded; Lock Screen banner; Mac window (test build) | ⌘⇧T press; menu-bar panel look; small/large/Lock Screen widgets; Live Activity Stop on device; haptics feel on device; onboarding skip with real iCloud data |
| **Phase 5 — 2nd iteration** (DD-60…66, [tickets](phase-5-tickets.md)) | Done (DD-60…66) | iCloud sync status; Mac Tasks empty state; chat field; timer chip; keyboard dismissal; due date picker; automatic Notion/Reminders import + calendar refresh | `checks/run.sh`; Mac + iOS builds | Deploy CloudKit schema to Production; same build source on both devices; live auto-import test |

**Known limits:** Notion is one-way (Notion wins); Calendar shows one calendar, read-only; Chat is read-only; widgets need the App Group (signed builds).

**Updating this section:** bump `MARKETING_VERSION` for user-visible releases and `CURRENT_PROJECT_VERSION` for every build you install on a device; update the table and add any new decision below in the same commit as the change.

## Decision Log

Newest first. One line per decision: what, why. Reverse a decision by adding a new row, not editing an old one.

| Date | Decision | Why |
|---|---|---|
| 2026-10-11 | Manual refresh (iPhone pull down, Mac ⌘R) runs the import, reloads the calendar and saves; it can't force a CloudKit download, so it shows the last sync result instead | SwiftData has no sync-now API; downloads arrive by push |
| 2026-10-11 | Deleting a session is permanent with a short inline Undo; no "exclude from stats" flag | Owner's choice; stats stay computed from entries with no new field |
| 2026-10-11 | Notion/Reminders import runs automatically while the app is active (activation + every 15 min, `AutoImport`): linked tasks refresh, new items with a matching project are added, unmatched wait for the sheet; Settings switch; duplicates from two devices merged by external ID | Owner approved adding without per-item review; still never creates projects |
| 2026-10-11 | No Firebase: stay on CloudKit; Settings shows the last sync result (`SyncMonitor`) | Mac and iPhone diverged because sync failed silently (likely undeployed Production schema / mixed TestFlight and Xcode builds), not because of CloudKit itself |
| 2026-10-11 | Design handoff removed after Phase 4; `DesignSystem.swift` (`DD`) and the shipped UI are now the design source | Fully implemented; keeps the repo lean |
| 2026-10-11 | Mac Quick Add saves on Return: the live "Do-Du will add" preview is the confirmation (typed syntax first, Foundation Models fill gaps; never a guessed project) | Handoff flow; the user sees every field before adding, so the "AI never writes silently" rule holds |
| 2026-10-11 | Mac idle stop is always on (5–60 min, default 10); stopping on sleep or lock has its own switch | Handoff Settings design; forgotten timers stay the main data risk, so only the sleep stop can be turned off |
| 2026-10-11 | Mac Quick Add: ⌘K inside the app plus a **global ⌥⌘K**; no Settings button in the menu-bar panel (app menu ⌘, only) | A global ⌘K would take the key from Slack, browsers and editors; owner wants no extra Settings buttons on Mac |
| 2026-10-11 | Onboarding's iCloud switch is a **real opt-out**: off opens the store without CloudKit; changing it later applies after relaunch | Owner's choice; a store's CloudKit mode is fixed when the container opens |
| 2026-10-11 | Mac global hotkey **⌘⇧T** toggles the timer from any app (Carbon `RegisterEventHotKey`), on by default with a Settings switch; Shortcuts actions stay | Owner asked for a real hotkey plus Shortcuts. Note: it takes ⌘⇧T from other apps (e.g. browsers' "Reopen closed tab") while on |
| 2026-10-11 | Widget and Live Activity start/stop open the app via `dodu://timer/toggle` (option A); the small Timer widget toggles on any tap | Widget processes never write to the store, so there is one writer and no CloudKit conflict from extensions. Cost: the app comes to the front |
| 2026-10-11 | Haptics only at timer start/stop/switch, project met, task done and AI errors; timer haptics hang off the running entry at the root (`TimerSync`) | One place catches every start path (buttons, widget, hotkey, Siri, sync). Few haptics keep "project met" meaningful |
| 2026-10-11 | iPhone keeps the **native** Liquid Glass tab bar (tinted forest) and shows the running timer in the native `tabViewBottomAccessory` | Handoff prefers native controls; the system bar can't take a solid forest selection capsule |
| 2026-10-11 | **Redesign** (handoff in `docs/design_handoff_dodu_app/`, git-ignored): timer-first Today, forest/sage/mint palette, SF Rounded numbers. Tokens live in `DesignSystem.swift` (`DD`); shared views in `DesignComponents.swift` | High-fidelity handoff; one source for tokens |
| 2026-10-11 | **Dark mode** adapted from the light tokens: brand hues kept, neutrals inverted, text on mint always forest (`DD.onMint`); forest splits into `DD.forest` (ink) and `DD.forestFill` (surfaces) | Handoff defines light only |
| 2026-10-11 | Project colours are six named swatches (`forest`, `sage`, `moss`, `seafoam`, `pine`, `slate`); old names map via `Palette.canonical` | New palette without a data migration |
| 2026-10-10 | Reminders import maps each **list name → project** (case-insensitive, never auto-created); links by `calendarItemExternalIdentifier` | Lists are how people already group reminders; external ID keeps one link across devices |
| 2026-10-10 | All imports share one `TaskSource` path: finished items aren't offered as new; linked tasks refresh title/done/due on every import | Same rules everywhere; fixed linked rows never refreshing |
| 2026-10-10 | Usage strings set as `INFOPLIST_KEY_*` build settings, using **full-access** keys (`NSCalendarsFullAccessUsageDescription`, `NSRemindersFullAccessUsageDescription`) | `requestFullAccessTo…` needs them; one place for both platforms |
| 2026-10-10 | One `ModelContainer` per process: `SharedStore.shared`, used by app UI and Siri/Shortcuts intents | Two CloudKit containers on one store conflict; objects can't be related across contexts |
| 2026-10-10 | Store lives in App Group `group.com.kv.Do-Du` (one-time move from the default location) | Widget extension must read the same data |
| 2026-10-10 | Widget extension gets an explicit `Do-DuWidget/Info.plist` with `NSExtension` | Generated plist can't express the dictionary; iOS refused to install without it |
| 2026-10-10 | Notion: one table, **one-way import, Notion wins**, `Notion-Version: 2022-06-28` | Simplest useful sync; newer versions move querying to data sources |
| 2026-10-10 | Calendar: **one** calendar, read-only; meeting time feeds Plan my day | Enough for planning; no write-back risk |
| 2026-10-10 | Siri "Add task" saves directly; the Siri dialog/Shortcuts result is the confirmation | Voice flow has no editor to confirm in |
| 2026-10-10 | Mac stops the running timer on sleep/lock or after idle (default 10 min), backdated to last activity | Forgotten timers were the main data-quality risk |
| 2026-10-10 | Mac menu-bar label is a **static symbol**; live clock only in the panel | A ticking label froze the app at launch |
| 2026-10-10 | iPhone keeps five tabs (Today, Tasks, Assistant, Stats, Projects); Settings is a gear on Today | Avoids the "More" tab; Mac uses the Settings window |
| 2026-10-10 | "Day starts at" setting (0:00–6:00); all day math goes through `DayMath` | Late-night work belongs to the previous day |
| 2026-10-10 | Claude model `claude-opus-5-5` with server-side `fallbacks: "default"`; one constant in `ClaudeClient` | Anthropic's current default; cost is the owner's call, easy to change |
| 2026-10-10 | AI split: on-device Apple Foundation Models for Quick Add; Claude for Plan, Recap, Chat | Free/private/offline where it's enough; Claude where reasoning matters |
| 2026-10-10 | AI never writes without confirmation; numbers always come from `Stats`/`AISnapshot`, never the model | Trustworthy data is the product |
| 2026-10-10 | Quick timer: time can run with **no task**; optional project; "No project" time counts toward no target until assigned | Starting work shouldn't require creating a task |
| 2026-10-10 | Self-checks in `checks/run.sh` instead of an XCTest target | Fast, no test target to maintain; covers core logic |
| 2026-10-10 | Sync: SwiftData + CloudKit private DB; models CloudKit-safe from day one; offline timer conflict → latest start wins | No backend; avoids later migration |
| 2026-10-10 | One **multiplatform target** (macOS 27 + iOS 27, iPhone only) | All code shared; resolves Open Question 4 |
| 2026-10-10 | Model named `TaskItem`, not `Task` | Avoids clashing with Swift concurrency `Task` |
| 2026-10-10 | "Enough" = every active project hits its **daily target** | Owner's choice; time-based and unambiguous |
| 2026-10-10 | Conventional Commits, one change per commit, no AI attribution trailers | Owner's commit guide (below) |

---

## For Coding Agents

- **Read first:** [Current Version](#current-version) and [Decision Log](#decision-log). Don't silently undo a logged decision; add a new row if you change one.
- **Stack:** SwiftUI + SwiftData, Xcode project at `Do-Du/Do-Du.xcodeproj`. Targets: `Do-Du` (multiplatform: macOS 27 + iOS 27 iPhone; all code shared, `#if os(macOS)` for platform-only UI) and `DoDuWidget` (Today widget + iOS Live Activity).
- **Folders** (`Do-Du/Do-Du/`, a synced group, so new files need no project edit): `App/` entry point and root view · `Core/` models, day math, stats, store, timer service · `DesignSystem/` tokens and shared views · `Features/<Area>/` screens (Today, Tasks, Projects, Stats, Assistant, Onboarding, Settings, Import) · `Services/` AI, integrations, system hooks (alerts, idle, hotkey, widget sync, Live Activity) · `Mac/` macOS-only window, settings and Quick Add panel. Plists and entitlements live in `Do-Du/Config/`. Files shared with the widget are listed by path in the project file; update them there if they move.
- **Data store:** always use `SharedStore.shared` (App Group store, CloudKit). Never create another `ModelContainer` in the app process; the widget opens the store read-only in its own process.
- **Style:** format with `xcrun swift-format format -i -r Do-Du/Do-Du Do-Du/Do-DuWidget checks/main.swift` (config in `.swift-format`). Comments are one line and only where they carry a why, an invariant or a platform quirk; no file headers.
- **Deep links** go through `DeepLink` (`dodu://…`); widgets and the Live Activity open the app rather than writing data.
- **Self-checks:** `checks/run.sh` compiles the pure/core files listed in it with `checks/main.swift` and runs assertions. Add a check for new logic and add new core files to the list. No XCTest target.
- **Integrations** plug in as a `TaskSource` (`TaskSource.swift`) and import through `ExternalImportSheet<Source>` and the automatic `AutoImport` (add new sources to its `run()`); don't touch core models for a new source.
- **Visuals:** the design source is `DesignSystem.swift` (the Phase 4 handoff is retired); use `DD` tokens and `DesignComponents` views; never hard-code colours. Text on mint uses `DD.onMint`. Check light and dark.
- **Privacy strings:** add `INFOPLIST_KEY_*` build settings on the `Do-Du` target (both configs), not per-platform plist files.
- **Timer writes** go through `TimerService` only. Never set `TimeEntry.end` on a running entry from a view.
- **Sample data:** DEBUG builds launched with `-seedSampleData YES` fill an empty store.
- **Onboarding:** the store opens only after onboarding on a fresh install (`OnboardingGate`); don't touch `SharedStore.shared` before `Do_DuApp` opens it. Widgets never create the store. DEBUG: `-forceOnboarding YES -onboardingStep N` shows a step.
- **Claude calls** go through `ClaudeClient` (raw HTTPS; no Swift SDK). Keep each feature's system prompt stable (it's cached) and put changing data in the user message. Echo assistant `content` back unchanged in tool loops. Send Claude an `AISnapshot` or tool results, never raw store dumps.
- **Day boundaries:** always use `DayMath.day` / `logicalDate` / `period` (they honour the "day starts at" setting); never `Calendar.startOfDay` for stats.
- **Sync:** SwiftData + CloudKit (private database). No custom backend.
- **Single user.** No auth, no accounts, no multi-tenant logic.
- Models: `Project`, `Category`, `TaskItem`, `TimeEntry` in `Models.swift`. Model is `TaskItem`, not `Task`, to avoid clashing with Swift concurrency `Task`. Keep them CloudKit-compatible (defaults on every property, optional relationships, no `.unique`).
- Secrets (API keys, OAuth tokens) go in Keychain, never in SwiftData or source.
- **AI (hybrid):** Apple Foundation Models (on-device) for natural-language task input (R7). Claude API (`claude-opus-5-5`, Anthropic's default model; one constant in `ClaudeClient`) for plan, recap, chat (R8–R10). User's Claude API key stored in Keychain.
- **Tickets:** [phase-1](phase-1-tickets.md), [phase-2](phase-2-tickets.md), [phase-3](phase-3-tickets.md), [phase-4 redesign](phase-4-tickets.md). Tick checkboxes as work lands; ticket files are the source of truth for status (the requirement checkboxes in this spec are scope, not status).

### Commit Guide

Follow [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <summary>

<body: what changed and why, wrapped at 72 chars>

Refs: DD-XX
```

- **Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `perf`, `style`.
- **Scope** (optional): area touched — `models`, `timer`, `today`, `stats`, `tasks`, `projects`, `sync`, `ios`, `ai`, `widget`, `intents`, `notion`, `calendar`, `reminders`, `settings`, `docs`.
- **Summary:** imperative mood ("add", not "added"), lowercase, no trailing period, ≤ 50 chars (hard max 72).
- **Body:** explain *why* and any non-obvious decision. Skip for trivial changes. Blank line between summary and body.
- **Footer:** `Refs: DD-XX` for the ticket. `BREAKING CHANGE: …` if data model changes need migration.
- **One logical change per commit.** Commit after each finished ticket (or meaningful slice of one). Don't mix refactors with features.
- **Every commit must build.** Run the build (and `checks/run.sh` when core logic changed) before committing.
- **Keep this file current.** A change that ships a feature, alters behaviour or reverses a decision updates [Current Version](#current-version) and/or the [Decision Log](#decision-log) in the same commit.
- **No AI attribution.** Do not add `Co-Authored-By` trailers or "Generated with" lines for AI assistants.
- **Never commit:** `.DS_Store`, `xcuserdata/`, `DerivedData/`, secrets, API keys.
- Stage files explicitly (`git add <paths>`), not `git add -A`, to avoid sweeping in junk.

Examples:
```
feat(timer): stop running timer when starting another

Only one TimeEntry may have end == nil. Starting a new timer closes
the current one at the same instant so time is never double-counted.

Refs: DD-05
```
```
docs: add phase 1 ticket breakdown
```

---

## Problem Statement

I work across several projects and never know when I've done "enough" for the day. Task apps track what's left, timers track hours, but nothing tells me whether today's work hit what I intended per project. Result: I keep working past reasonable limits or end the day feeling unproductive even when I wasn't. Do-Du combines tasks, time tracking, and per-project targets so the app can give a clear verdict each day.

## Goals

1. **Clear daily verdict** — by end of day, app shows for each project whether its daily target was met, and an overall "enough" state.
2. **Low-friction tracking** — start/stop timer on a task in ≤ 2 clicks/taps from any main screen.
3. **Trustworthy data** — ≥ 90% of working time is captured by timer (vs. forgotten/untracked), measured by self-check weekly.
4. **Less planning overhead** — AI assistant produces a usable day plan in < 30 seconds from existing tasks + targets.
5. **One place** — same data on Mac and iPhone, synced within seconds.

## Non-Goals (v1)

| Non-goal | Why |
|---|---|
| Two-way integrations (writing back to Notion, Calendar, Reminders) | Phase 3 shipped one-way/read-only only. Two-way Notion needs a conflict rule (Q7). |
| Multi-user, sharing, teams | Personal app. Adds auth + permissions for zero value. |
| Billing / invoicing from tracked time | Not the purpose. Export CSV later if needed. |
| Android / Windows / web | Apple-only via SwiftUI. |
| Gamification (streaks, badges, points) | Risk of turning "enough" into "more". Revisit only if motivation drops. |
| Automatic activity tracking (app/window monitoring) | Privacy + complexity. Manual timer is the source of truth. |

## Core Concepts

| Concept | Definition |
|---|---|
| **Project** | Container for work (e.g. "Do-Du", "Client X"). Has a **daily target** (minutes) and optional active weekdays. |
| **Category** | Cross-project tag describing work type (e.g. Deep Work, Admin, Meetings, Learning). A task has 0–1 category. |
| **Task** | Unit of work. Belongs to exactly one project. Has title, optional notes, optional due date, optional estimate, status (open / done). |
| **Time Entry** | One continuous timer session: start, end, and a task — or, for a **quick session**, no task and an optional project. Quick sessions without a project are "No project" time: tracked, but not counted toward any target until assigned. |
| **Enough** | A project is "enough" today when tracked time ≥ its daily target. Day is "enough" when every project scheduled for today is enough. |

## User Stories

**Planning**
- As me, I want to create projects with a daily time target so that "enough" is defined before the day starts.
- As me, I want to choose which weekdays a project is active so that weekend days don't count as failures.
- As me, I want to group tasks by project and filter by category so that I see work by context.
- As me, I want to type "Add 2h design review to Do-Du tomorrow" so that I capture tasks without forms.
- As me, I want the AI to propose today's plan from open tasks and project targets so that I start working instead of deciding.

**Doing**
- As me, I want to start a timer on any task in one action so that tracking never slows me down.
- As me, when I'm too lazy to create a task, I want to start a timer with no task (optionally picking a project) so that I still track the work.
- As me, I want to assign a project to task-less time later so that it counts toward that project's target.
- As me, I want only one timer running at a time, and starting a new one stops the old one, so that time is never double-counted.
- As me, I want the running timer visible in the macOS menu bar and iOS Live Activity so that I always know it's on.
- As me, I want to add or edit time entries manually so that I can fix a forgotten start/stop.
- As me, I want a warning when a timer runs past a threshold (e.g. 3h) so that a forgotten timer doesn't corrupt my stats.

**Reviewing**
- As me, I want a "Today" view showing progress bar per project vs. target so that I know at a glance what's left.
- As me, I want a clear "You've done enough today" state so that I can stop working without guilt.
- As me, I want weekly and monthly stats (time by project, by category, targets hit) so that I see patterns.
- As me, I want an AI daily/weekly recap so that I get a short written summary of what I did.
- As me, I want to ask the AI questions about my history ("How much deep work last month?") so that I don't build reports manually.

**Edge cases**
- As me, if the app quits or the device sleeps while a timer runs, I want the timer to keep correct elapsed time so that no time is lost.
- As me, if I start a timer on Mac and stop it on iPhone, I want one consistent entry so that sync never duplicates time.
- As me, on a day with no active projects, I want the Today view to say "Rest day" instead of showing 0%.
- As me, when a timer runs across midnight, I want the entry split at day boundary for stats so that each day is counted correctly.

## Requirements

### P0 — Must-Have (Phase 1: Core Loop)

**R1. Projects & categories**
- [ ] CRUD projects: name, color, daily target (minutes), active weekdays, archived flag.
- [ ] CRUD categories: name, color.
- [ ] Archiving a project hides it from Today but keeps history.

**R2. Tasks**
- [ ] CRUD tasks: title, project (required), category (optional), notes, due date, estimate, status.
- [ ] List grouped by project; filter by category, status, due today.
- [ ] Mark done / reopen.

**R3. Timer**
- [ ] Start/stop on any task. Max one running timer globally (across devices).
- [ ] Quick timer: start without a task from Today / menu bar, optionally with a project. Project can be set while running or later; "No project" time shows on Today and Stats but counts toward no target.
- Given timer A is running, when I start timer on task B, then A stops at that instant and B starts.
- [ ] Elapsed time computed from stored `start` timestamp (not an in-memory counter) — survives quit, sleep, crash.
- [ ] Manual entry add/edit/delete. End must be after start; entries for the same time span cannot overlap.
- [ ] Long-run warning notification after configurable threshold (default 3h).
- [ ] macOS menu bar item showing running task + elapsed time, with stop button.

**R4. Today view & "Enough" verdict**
- [ ] Per active project: tracked today / target, progress bar.
- [ ] Overall state: *Not yet* / *Enough* / *Rest day*.
- [ ] Day boundary = local midnight (configurable "day starts at" hour is P1).
- [ ] Entries crossing midnight are split across days for all calculations.

**R5. Statistics**
- [ ] Day / week / month views.
- [ ] Total time by project and by category.
- [ ] Targets hit: count of "enough" days per period.
- [ ] Per-project trend (time per day, simple bar chart via Swift Charts).

**R6. Multi-device**
- [ ] iOS target with same feature set (R1–R5), layout adapted for iPhone.
- [ ] SwiftData + CloudKit private DB sync.
- Given timer started on Mac, when I open iPhone, then the same timer shows running with correct elapsed time.
- [ ] Conflict: if two devices start timers offline, on sync the later `start` wins and the earlier timer is stopped at the later start time.

### P1 — Nice-to-Have (Phase 2: AI Assistant)

**AI provider split (decided 2026-10-10)**

| Feature | Engine | Why |
|---|---|---|
| R7 Natural-language input | Apple Foundation Models (on-device) | Fast, offline, free, private; structured output into `Task` fields is a small task |
| R8 Plan my day | Claude API (`claude-opus-5-5`) | Multi-step reasoning across tasks + targets |
| R9 Recap | Claude API | Better prose and judgment |
| R10 Chat over my data | Claude API (tool use) | Needs reliable tool calling over local queries |

- [ ] Settings screen to enter/remove Claude API key (Keychain).
- [ ] No key or offline → R8–R10 show clear "needs Claude API key / connection" state; R7 and all P0 features keep working.
- [ ] Device without Apple Intelligence → R7 falls back to the plain task form.
- [ ] Only data needed for a request is sent to Claude (computed stats, relevant tasks), never full DB dump.

**R7. AI — Natural-language input**
- [ ] Text field (and macOS global shortcut) parsing into task(s): title, project, category, due date, estimate.
- [ ] Shows parsed result for confirmation before saving. Never writes data silently.
- [ ] Unknown project name → ask, don't auto-create.

**R8. AI — Plan my day**
- [ ] Input: open tasks, due dates, estimates, today's project targets, yesterday's carryover.
- [ ] Output: ordered list of tasks with suggested time blocks that sum to targets.
- [ ] User can accept, reorder, or discard. Accepted plan = "Today's plan" list.

**R9. AI — Recap**
- [ ] Daily recap (on demand + optional end-of-day notification) and weekly recap.
- [ ] Includes: time per project vs target, tasks completed, enough/not enough verdict, one short observation.
- [ ] Numbers come from computed stats, not model guesses — model only writes prose around provided figures.

**R10. AI — Chat over my data**
- [ ] Chat panel answering questions about tasks, time entries, stats.
- [ ] Implemented via tool calls that query local data (e.g. `get_time_by_project(range)`), not by dumping full DB into prompt.
- [ ] Read-only by default; any write action requires confirmation (same flow as R7).

**Other P1**
- [ ] Configurable day start hour (e.g. day ends at 3am for late work).
- [ ] iOS Live Activity / Dynamic Island for running timer.
- [ ] Widgets: Today progress (macOS + iOS).
- [ ] Optional Pomodoro mode (work/break intervals) on top of the timer.
- [ ] CSV export of time entries.

### P2 — Phase 3: Integrations (shipped one-way; two-way is future)

- **Notion:** two-way sync of tasks with a Notion database. → Task model needs `externalSource` + `externalID` fields from day one.
- **Calendar (EventKit):** show today's events in Today view; meetings reduce available time in AI plan; optionally write time entries back as calendar blocks.
- **Apple Reminders**, others as needed. → Integrations live behind one `TaskSource` boundary so each new one doesn't touch core models.
- **Apple Shortcuts / App Intents:** start/stop timer, add task via Siri.

## Data Model (sketch)

```
Project    name, colorName, dailyTargetMinutes, activeWeekdaysMask, isArchived, createdAt
           tasks[] (cascade), looseEntries[] (quick-timer entries, cascade)
Category   name, colorName, tasks[] (nullify)
TaskItem   title, notes, project?, category?, dueDate?, estimateMinutes?, isDone, completedAt?,
           externalSource? ("notion" | "reminders"), externalID?,
           plannedFor?, planOrder, plannedMinutes?, entries[] (cascade), createdAt
TimeEntry  task?, project?, start, end?   // end == nil → running
                                         // project only for task-less (quick) entries
```

Invariants: at most one `TimeEntry` with `end == nil`; `end > start`; derived stats are computed, not stored.

## Success Metrics

**Leading (first 2 weeks of daily use)**
| Metric | Target | Stretch |
|---|---|---|
| Days with ≥ 1 time entry / working days | 90% | 100% |
| Timer started within 2 clicks/taps from main screens | 100% of paths | — |
| Manual time-entry edits per week (proxy for missed tracking) | ≤ 5 | ≤ 2 |
| AI plan accepted (with or without edits) | 50% of days used | 75% |

**Lagging (after 1–2 months)**
| Metric | Target |
|---|---|
| Days I stop work at "Enough" without guilt (self-rated in recap, yes/no) | ≥ 70% |
| Days marked "Enough" / active days | Stable or rising; not a pressure metric |
| Still using Do-Du daily after 8 weeks | Yes |

Measurement: computed in-app from SwiftData; self-rating is a one-tap question in daily recap.

## Open Questions

| # | Question | Owner | Blocking? |
|---|---|---|---|
| 1 | ~~AI provider~~ **Resolved 2026-10-10:** hybrid — on-device for NL input, Claude for plan/recap/chat. See Phase 2 table. | — | — |
| 2 | Should "enough" also include must-do tasks, or stay purely time-based per project? | Me | No — start time-based |
| 3 | Weekly targets in addition to daily (e.g. 10h/week, flexible across days)? | Me | No |
| 4 | ~~Minimum iOS version~~ **Resolved 2026-10-10:** iOS 27, matching macOS 27. | — | — |
| 5 | Can a task move to another project after time is logged? If yes, history moves with it. | Me | No |
| 6 | What happens to "enough" if target is changed mid-day — use target at start of day or current? | Me | No — default: current |
| 7 | Notion two-way conflict rule (Do-Du wins? last-write?) — **v1 decided 2026-10-10:** one-way import, Notion wins. | Me | Blocks two-way sync only |

## Timeline & Phasing

No hard deadlines (personal project). Ship each phase and use it daily before starting the next.

| Phase | Scope | Done when | Status |
|---|---|---|---|
| **1. Core loop** | R1–R6: projects, categories, tasks, timer, Today verdict, stats, Mac + iPhone sync | Used daily for 1 week on both devices without data issues | Code done; sync test pending |
| **2. AI assistant** | R7 (on-device) + R8–R10 (Claude) + chosen P1 extras | Recap used ≥ 4 days/week | Code done; live Claude test pending |
| **3. Integrations** | Notion, Calendar, Reminders, App Intents | Each integration behind `TaskSource`; core models untouched | Code done (one-way); live tests pending |

**Suggested Phase 1 order:** data models → task CRUD (macOS) → timer + menu bar → Today view → stats → add iOS target → CloudKit sync → cross-device timer tests.

**Risks**
- CloudKit sync conflicts on running timer → test early, not last.
- Forgotten timers silently inflating stats → long-run warning is P0 for this reason.
- AI scope creep → AI never writes without confirmation; numbers always from computed stats.
