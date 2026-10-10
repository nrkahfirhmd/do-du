# Do-Du — Cross-Device Sync Test (DD-13)

Manual test. Needs a real Mac and iPhone signed in to the **same iCloud account**, both running a build signed with team `84L3QCBHMU` and the `iCloud.com.kv.Do-Du` container.

The conflict rule itself is covered automatically by `checks/run.sh` ("latest start wins"). This script checks that it holds over real CloudKit sync.

## Setup

1. Open `Do-Du/Do-Du.xcodeproj` in Xcode → target **Do-Du** → *Signing & Capabilities*. Confirm the iCloud container `iCloud.com.kv.Do-Du` is checked (Xcode registers it on first build).
2. Run on Mac (My Mac) and on iPhone (your device).
3. Both: Settings → Sync shows **iCloud sync on**.
4. Create project **Sync Test** (target 1h, all days) and tasks **A** and **B** on the Mac. Wait until they appear on the iPhone (normally under a minute; bring the app to foreground).

Allow ±10 s for clocks, and up to ~1 min per sync step.

## Cases

| # | Steps | Expected | Pass |
|---|---|---|---|
| 1 | Mac: start **A**. iPhone: open Today. | iPhone shows **A** running, same elapsed time (±10 s). | [ ] |
| 2 | With **A** running from case 1, iPhone: tap stop. Mac: wait for sync. | Mac shows no running timer. **A** has exactly one entry with the iPhone stop time. | [ ] |
| 3 | Both offline (airplane mode / Wi-Fi off). Mac: start **A**. Wait 1 min. iPhone: start **B**. Both back online. Open app on both. | Only **B** is running on both. **A**'s entry ends at **B**'s start time. No overlap in Stats. | [ ] |
| 4 | Mac: Tasks → **A** → Time Entries → edit an entry's start by −10 min. | iPhone shows the same edited entry and an updated Today total. | [ ] |
| 5 | iPhone: Projects → delete **Sync Test**. | Mac: project, its tasks and entries are gone. Stats show no orphaned time. | [ ] |
| 6 | Sign out of iCloud on iPhone, relaunch. | Today shows "Not signed in to iCloud…". App still works locally. | [ ] |
| 7 | Mac: start a timer, quit the app, wait 2 min, reopen. | Same timer still running; elapsed includes the time the app was closed. | [ ] |

## If something fails

Note the case number, both device times, and what each screen showed. CloudKit logs: Console.app → filter `CloudKit` / `com.kv.Do-Du`.
