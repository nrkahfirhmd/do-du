# Do-Du — Phase 2 Tickets (AI Assistant)

Source spec: [AGENTS.md](AGENTS.md) — requirements R7–R10 + P1 extras.
Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days. Work top to bottom; each ticket lists blockers.

**Engines:** on-device Apple Foundation Models for R7. Claude API (`claude-opus-5-5`, raw HTTPS — no official Swift SDK) for R8–R10.

**Rules for every AI feature**
- AI never writes data without the user confirming.
- Numbers shown to the user come from `Stats`/`DayMath`, never from the model.
- Claude gets only the data a request needs (a compact snapshot), never the whole store.
- No key / offline / refusal → clear message; every non-AI feature keeps working.

**Phase done when:** recap used ≥ 4 days/week (spec).

---

## DD-20 · Claude API key in Keychain + AI settings — S
**Req:** R8–R10 · **Blocked by:** —

- [x] `Keychain` helper (Security framework): save / read / delete one generic password item.
- [x] Settings → "Claude" section: secure field, Save, Remove, status line (key set / not set). Key never shown back in full.
- [x] Key never stored in SwiftData, UserDefaults, logs or source.

## DD-21 · Claude client — M
**Req:** R8–R10 · **Blocked by:** DD-20

- [x] `ClaudeClient` over `URLSession`: `POST /v1/messages`, headers `x-api-key`, `anthropic-version: 2023-06-01`.
- [x] Model `claude-opus-5-5`, `output_config.effort` per feature, server-side `fallbacks: "default"` (`anthropic-beta: server-side-fallback-2026-07-01`).
- [x] Optional structured output (`output_config.format` JSON schema) and client tools with a tool-use loop. History is append-only (assistant `content` echoed back unchanged).
- [x] Typed errors: no key, offline, 401 bad key, 429/529 busy (one retry after `retry-after`), refusal, other HTTP. Each maps to a short user-facing message.
- [x] Self-check: request body encodes correctly; canned responses decode text, `tool_use`, and `refusal`.

## DD-22 · AI data snapshot — M
**Req:** R8–R10 · **Blocked by:** —

Pure function: models + date range → compact text Claude can read.

- [x] Projects (target, active today?), tracked per project for the range, "No project" time, per-day verdicts.
- [x] Open tasks (title, project, category, due, estimate) and tasks completed in range.
- [x] Deterministic ordering (stable prompt → cacheable), durations as minutes.
- [x] Self-check against fixed data.

## DD-23 · Natural-language task input (on-device) — M
**Req:** R7 · **Blocked by:** —

- [x] "Quick Add" (sparkles) on Tasks, ⌘K on Mac: type a sentence, e.g. "Add 2h design review to Do-Du tomorrow". Verified on iOS 27 simulator: title, project, due tomorrow, 2h estimate all filled.
- [x] `FoundationModels` guided generation into a `@Generable` draft: title, project name, category name, due-in-days, estimate minutes.
- [x] Project/category matched case-insensitively to existing ones. Unknown project → editor opens with project unselected (never auto-created).
- [x] Always opens the task editor pre-filled for confirmation; nothing saved silently.
- [x] Model unavailable (no Apple Intelligence, not ready) → editor opens with the text as title.

## DD-24 · Recap (daily / weekly) — M
**Req:** R9 · **Blocked by:** DD-21, DD-22

- [x] Assistant tab (Settings moved to a gear on Today on iPhone to keep five tabs) → Recap: Today / This week. Shows computed numbers first (tracked, per project vs target, enough days, No project time, tasks done), then Claude's short write-up.
- [x] Prompt: use only provided numbers, one observation, under ~120 words, mention No project time if any.
- [x] Optional daily reminder (Settings → Recap: off / time). Repeating local notification with generic text (a repeating trigger can't compute totals at fire time); no network call in the background.
- [ ] **Not yet verified against the live API** — needs your Claude key. No-key path verified in simulator.

## DD-25 · Plan my day — M
**Req:** R8 · **Blocked by:** DD-21, DD-22

- [x] `TaskItem` gains `plannedFor: Date?`, `planOrder: Int`, `plannedMinutes: Int?` (optional, CloudKit-safe).
- [x] "Plan my day" on Today → Claude returns structured JSON: ordered task picks with minutes and a one-line reason, plus a short note. Picks reference tasks by index into the list sent; unknown indexes dropped.
- [x] Review sheet: accept, reorder, remove items, or discard. Accept writes the plan; nothing written before.
- [x] Today shows "Plan" section in order with start buttons; clear plan.
- [ ] **Not yet verified against the live API** — needs your Claude key. No-key path, store migration and JSON mapping verified.

## DD-26 · Chat over my data — L
**Req:** R10 · **Blocked by:** DD-21, DD-22

- [x] Assistant tab → Recap | Chat switch → Chat. Conversation in memory only (not synced).
- [x] Read-only client tools: `time_summary(start, end, group_by)`, `list_tasks(status, project, due_before)`, `day_verdicts(start, end)`. Results computed locally.
- [x] Tool-use loop with a step cap; errors returned as `is_error` tool results.
- [x] No write tools in v1 (spec: writes need confirmation; none needed yet).
- [ ] **Not yet verified against the live API** — needs your Claude key. Tools verified by `checks/run.sh`; UI verified in simulator.

## DD-27 · Day start hour — S
**Req:** P1 · **Blocked by:** —

- [x] Settings: day starts at 0:00–6:00 (default 0). Work before that hour counts toward the previous day.
- [x] `DayMath.day` honours it everywhere (Today, Stats, verdicts, recap). Self-check.

## DD-28 · CSV export — S
**Req:** P1 · **Blocked by:** —

- [x] Settings → Export time entries (CSV): date, start, end, minutes, project, task, category.
- [x] Save panel (fileExporter, Mac + iPhone); RFC 4180 quoting checked in `checks/run.sh`.

## DD-29 · Pomodoro reminder — S
**Req:** P1 · **Blocked by:** —

- [ ] Settings: Pomodoro off / on with work length (default 25 min).
- [ ] When on, a timer start schedules a "Time for a break" notification at the work length; stop cancels it.

## DD-30 · Widgets + Live Activity — L · **Needs Xcode first**
**Req:** P1 · **Blocked by:** manual setup

- [ ] **Manual:** in Xcode add a Widget Extension target and an App Group (`group.com.kv.Do-Du`) to app + extension (registers with your team).
- [ ] Move the SwiftData store into the App Group container (data migration).
- [ ] Today progress widget (macOS + iOS), running-timer Live Activity / Dynamic Island (iOS).

---

## Order

1. **DD-20 → DD-21**, **DD-22**, **DD-23**, **DD-27** (independent).
2. **DD-24 → DD-25 → DD-26** (all need DD-21 + DD-22).
3. **DD-28**, **DD-29** any time.
4. **DD-30** after manual Xcode setup.
