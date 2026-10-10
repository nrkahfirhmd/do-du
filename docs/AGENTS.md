# Do-Du — Product Spec

> Personal to-do list + work timer. Purpose: answer one question at end of every day — **"Did I do enough today?"** — with data, not guilt.

**Owner:** Kahfi R · **Status:** Draft v1 · **Last updated:** 2026-10-10

---

## For Coding Agents

- **Stack:** SwiftUI + SwiftData, Xcode project at `Do-Du/Do-Du.xcodeproj`. One multiplatform target: macOS 27 + iOS 27 (iPhone). All code shared; use `#if os(macOS)` for platform-only UI (e.g. `MenuBarExtra`).
- **Self-checks:** `checks/run.sh` compiles core files (models, `DayMath`, `Stats`, `TimerService`) with `checks/main.swift` and runs assertions. Run it whenever core logic changes. No XCTest target yet.
- **Timer writes** go through `TimerService` only. Never set `TimeEntry.end` on a running entry from a view.
- **Sample data:** DEBUG builds launched with `-seedSampleData YES` fill an empty store.
- **Sync:** SwiftData + CloudKit (private database). No custom backend.
- **Single user.** No auth, no accounts, no multi-tenant logic.
- **Build in phase order** (see [Timeline](#timeline--phasing)). Do not start integrations before core loop works.
- Models: `Project`, `Category`, `TaskItem`, `TimeEntry` in `Models.swift`. Model is `TaskItem`, not `Task`, to avoid clashing with Swift concurrency `Task`. Keep them CloudKit-compatible (defaults on every property, optional relationships, no `.unique`).
- Secrets (API keys, OAuth tokens) go in Keychain, never in SwiftData or source.
- **AI (hybrid):** Apple Foundation Models (on-device) for natural-language task input (R7). Claude API (`claude-sonnet-5-5`) for plan, recap, chat (R8–R10). User's Claude API key stored in Keychain.
- **Tickets:** Phase 1 breakdown in [phase-1-tickets.md](phase-1-tickets.md). Tick checkboxes as work lands.

### Commit Guide

Follow [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<scope>): <summary>

<body: what changed and why, wrapped at 72 chars>

Refs: DD-XX
```

- **Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `perf`, `style`.
- **Scope** (optional): area touched — `models`, `timer`, `today`, `stats`, `tasks`, `projects`, `sync`, `ios`, `docs`.
- **Summary:** imperative mood ("add", not "added"), lowercase, no trailing period, ≤ 50 chars (hard max 72).
- **Body:** explain *why* and any non-obvious decision. Skip for trivial changes. Blank line between summary and body.
- **Footer:** `Refs: DD-XX` for the ticket. `BREAKING CHANGE: …` if data model changes need migration.
- **One logical change per commit.** Commit after each finished ticket (or meaningful slice of one). Don't mix refactors with features.
- **Every commit must build.** Run the build (and `checks/run.sh` when core logic changed) before committing.
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
| Notion / Calendar / Reminders integrations | Ship core loop first. Phase 3. Data model must not block them (see P2). |
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
| **Time Entry** | One continuous timer session: task, start, end. Time always attaches to a task (and therefore a project). |
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
| R8 Plan my day | Claude API | Multi-step reasoning across tasks + targets |
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

### P2 — Future (Phase 3: Integrations) — design for, don't build

- **Notion:** two-way sync of tasks with a Notion database. → Task model needs `externalSource` + `externalID` fields from day one.
- **Calendar (EventKit):** show today's events in Today view; meetings reduce available time in AI plan; optionally write time entries back as calendar blocks.
- **Apple Reminders**, others as needed. → Integrations live behind one `TaskSource` boundary so each new one doesn't touch core models.
- **Apple Shortcuts / App Intents:** start/stop timer, add task via Siri.

## Data Model (sketch)

```
Project    id, name, color, dailyTargetMinutes, activeWeekdays[], isArchived, createdAt
Category   id, name, color
TaskItem   id, title, notes, projectID, categoryID?, dueDate?, estimateMinutes?,
           status(open|done), completedAt?, externalSource?, externalID?, createdAt
TimeEntry  id, taskID, start, end?          // end == nil  → running
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
| 4 | Minimum iOS version? (affects SwiftData/CloudKit features, Live Activities) | Eng | Blocks Phase 1 iOS work |
| 5 | Can a task move to another project after time is logged? If yes, history moves with it. | Me | No |
| 6 | What happens to "enough" if target is changed mid-day — use target at start of day or current? | Me | No — default: current |
| 7 | Notion sync direction & conflict rule (Notion wins? Do-Du wins? last-write?) | Me / eng | Blocks Phase 3 only |

## Timeline & Phasing

No hard deadlines (personal project). Ship each phase and use it daily before starting the next.

| Phase | Scope | Done when |
|---|---|---|
| **1. Core loop** | R1–R6: projects, categories, tasks, timer, Today verdict, stats, Mac + iPhone sync | Used daily for 1 week on both devices without data issues |
| **2. AI assistant** | R7 (on-device) + R8–R10 (Claude) + chosen P1 extras | Recap used ≥ 4 days/week |
| **3. Integrations** | Notion, Calendar, Reminders, App Intents | Each integration behind `TaskSource`; core models untouched |

**Suggested Phase 1 order:** data models → task CRUD (macOS) → timer + menu bar → Today view → stats → add iOS target → CloudKit sync → cross-device timer tests.

**Risks**
- CloudKit sync conflicts on running timer → test early, not last.
- Forgotten timers silently inflating stats → long-run warning is P0 for this reason.
- AI scope creep → AI never writes without confirmation; numbers always from computed stats.
