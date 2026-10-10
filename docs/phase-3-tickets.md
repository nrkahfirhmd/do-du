# Do-Du — Phase 3 Tickets (Integrations)

Source spec: [AGENTS.md](AGENTS.md) — P2. Scoped 2026-10-10: Notion (one table, one-way import), Calendar (one calendar, read-only), then App Intents.
Size: **S** ≤ half day · **M** ~1 day · **L** 2–3 days.

**Rules for every integration**
- Core models stay untouched; sources plug into `TaskSource` (`TaskSource.swift`) and map onto `TaskItem` via `externalSource` / `externalID`.
- Secrets in Keychain, never in SwiftData or source.
- External data is untrusted: tolerate any property schema, never auto-create projects, confirm before writing.

---

## DD-31 · TaskSource + Notion one-way import — M

- [x] `TaskSource` protocol + `ExternalDraft` (source-agnostic).
- [x] `NotionClient` over `URLSession`: token in Keychain, database ID (bare or URL) in Settings, `POST /v1/databases/{id}/query` with pagination.
- [x] Schema-tolerant mapping: first title prop → title; checkbox (else status name) → done; first date → due; select (else rich text) → project, matched case-insensitively, never auto-created.
- [x] Tasks → Import sheet: preview new rows with per-row project picker; Import inserts new + refreshes title/done/due on linked rows; skips unresolvable projects with a count.
- [x] Typed errors (no token/DB, offline, 401, 404, 429) + Settings Test Connection.
- [x] Self-check (`checks/run.sh`): ID forms, error mapping, parse fixture, apply insert/update/skip.
- [ ] **Not yet verified against the live API** — needs your Notion token + database ID.

## DD-32 · Apple Calendar, one calendar, read-only — M

- [ ] Settings: pick 1 `EKCalendar`; `NSCalendarsUsageDescription` + Calendar permission.
- [ ] Today view shows today's events from that calendar.
- [ ] Plan my day subtracts meeting time from available time.
- [ ] No writes in v1 (focus-block write-back is a later opt-in).

## DD-33 · App Intents / Shortcuts — S–M

- [ ] Intents: start timer (task picker), stop timer, add task (opens Quick Add prefill).
- [ ] Global Quick Add hotkey on macOS (R7 promised it; today it's ⌘K in-app only).

---

## Order

1. **DD-31** (this branch), verified against the live Notion API.
2. **DD-32**, then **DD-33**.
3. Later, only on request: two-way Notion sync (needs conflict rule, spec open Q7), Reminders import (reuses `TaskSource`).
