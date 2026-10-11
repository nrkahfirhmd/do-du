# Do-Du

Personal to-do list and work timer for macOS and iPhone that answers one question: **did I do enough today?** Each project gets a daily target; the timer tracks time against it and Today gives the verdict.

## Build

- Xcode with the macOS 27 / iOS 27 SDKs. Open `Do-Du/Do-Du.xcodeproj`, scheme **Do-Du** (multiplatform app + `DoDuWidget`).
- Sync needs the iCloud container and App Group (`group.com.kv.Do-Du`) on your signing team; unsigned builds fall back to a local store.
- Self-checks: `./checks/run.sh`.
- Format: `xcrun swift-format format -i -r Do-Du/Do-Du Do-Du/Do-DuWidget checks/main.swift`.

## Layout

```
Do-Du/
  Do-Du/            app sources (synced group)
    App/            entry point, root view, sample data
    Core/           models, day math, stats, store, timer service, deep links
    DesignSystem/   tokens (DD) and shared views
    Features/       Today, Tasks, Projects, Stats, Assistant, Onboarding, Settings, Import
    Services/       AI (Claude, on-device parsing), integrations, system hooks
    Mac/            macOS window, Settings window, Quick Add panel
  Do-DuWidget/      widgets and Live Activity
  Config/           Info.plists and entitlements
checks/             assertion-based self-checks
docs/               spec (AGENTS.md), tickets, app icon sources
```

See [docs/AGENTS.md](docs/AGENTS.md) for the spec, current version and decision log.
