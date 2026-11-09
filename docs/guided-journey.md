# My time with God — v0.2.0 pilot

Open **Home → My time with God** or the journal entry in **Saved**. Start with
the current Bible chapter, or optionally choose Anxiety, Stress, Grief,
Loneliness, or Joy. A check-in is never required to read the Bible.

## Guided sessions (phase 8)

Move through Pause, Read, Reflect, Pray, and Live in any order. Every step is
skippable. Open passage in the Bible uses the regular reader with the full
chapter and current translation available. Continue reflection returns to the
saved session. The latest saved entry is reloaded before resuming; deleted
entries are not recreated. Completing a session does not mark a chapter read.

Reflection, prayer, and response fields autosave. Back/Save & close waits for
the write and reports a failure rather than silently discarding changes.
Unfinished sessions are drafts. A completed session may be reopened and edited.
The optional action checkbox is the reader's own record, not a spiritual score.
Focus Mode still counts only eligible time in the regular Bible reader;
reflection/prayer forms do not silently earn reading-time credit.

## Contextual theme guides (phase 9)

Catalog version 1 contains three passages for each of the five themes. Each
guide has a passage reference, contextual introduction, reflection question,
prayer starting point, and practical invitation. Scripture comes from the
selected licensed Bible. Editorial guidance is labeled separately.

The English introductions and prompts are original SELAH app content developed
for this pilot, not copied devotionals or additional Bible text. Reference
coverage and surrounding narrative/context were checked during development;
no pastoral or independent theological review is claimed. Feedback and review
by trusted readers/pastoral contacts are encouraged before wider distribution.
The catalog is maintained in `lib/features/growth/growth_catalog.dart`.

Selected theme labels are not stored as a separate mood diary. Content IDs and
their most recent use are retained locally for least-recently-used rotation;
saved session references/titles may still reveal the subject a reader chose.
This is reflective guidance, not a diagnosis or a promise of emotional relief.

## Prayer journal and reminders (phase 10)

Write a prayer using the + button. Add a title, a category (Request, Gratitude,
Lament, Waiting), and your words. Personal statuses are Still praying, Answered,
or Archived; SELAH never decides which applies. Add dated updates as time passes.
An unfinished update is saved as a draft. Delete entries only after confirmation.

The optional Android morning and bedtime reminders each have a switch and time picker,
defaulting to 8:00 AM and 9:00 PM in device local time. Existing daily reminders
retain their chosen time as the morning reminder; bedtime starts disabled.
Enabling a reminder asks for a time, then notification permission
on Android 13+. It uses inexact alarms, not an exact-alarm or foreground-service
permission. Android may delay delivery. Morning says "Begin your day with God";
bedtime says "A quiet moment before sleep". Tapping either opens the Bible. It does
not expose prayers, moods, or journal text. Boot, clock/timezone changes, app
updates, and reopening the app reschedule an enabled reminder. Turning it off
cancels its alarm and posted notification. Force-stopping the app or vendor
battery restrictions may prevent delivery until the app is opened again.

Reminder settings and OS permissions stay on that Android installation and
are not enabled by importing a journal backup. Reminders are not offered on
web/iOS in this release.

## Chosen sharing (phase 12)

Use Preview sharing in a session/prayer or Share passage in reader verse actions.
Choose which fields to include and inspect the full preview. Private reflection,
prayer, and response fields are unchecked by default. Prayer updates, drafts,
statuses, and theme-history records are never automatically included. Scripture
sharing retains the selected edition's attribution/license information.

Share opens the platform chooser through share_plus; SELAH does not choose a
recipient or post automatically. Copy is available where platform sharing is
unavailable. Leaving the chooser does not send anything. No groups, accounts,
prayer feed, or server-side journal are added.

## Storage and backups

Drift schema v4 adds separate growth_entries and growth_seen tables. Existing
Bible annotations, downloads, and reading progress remain separate. Backup
format v2 contains guided sessions and prayers, including update drafts, and
continues to read v1 annotation backups. Merge keeps local conflicts by entry
ID; Replace removes entries absent from the backup, including all journals if
the chosen old backup contains none. The restore preview and confirmation
describe these effects. The passage-rotation cache is not exported.

Local storage and backup files are not described as encrypted. Someone with
access to an unlocked device or an exported backup may read its contents. No
AI API, analytics service, or cloud account receives the private writing.

## Verification

63 Flutter tests cover the original app and new catalog reference coverage,
theme rotation, SQLite close/reopen with journal drafts and updates, backup
round trips, merge/replace, v1 compatibility, invalid journal records, autosave,
Home → guided session → Bible → reflection, preservation of newer saved edits,
deleted-session handling, and opt-in private share preview content.

Android debug/release builds pass. A native instrumentation smoke test verifies
reminder enable/schedule, asynchronous notification delivery with generic text,
a launch intent, and disable. Emulator UI checks cover theme selection and
opening the Bible with Continue reflection. The platform chooser check stops
before selecting a recipient. Web release/offline packaging compiles; iOS and
broader physical-device behavior remain unverified.

Run the native smoke test only on a test emulator using the debug app and
`app-debug-androidTest.apk`, then
`adb shell am instrument -w com.example.selah.test/com.example.selah.JourneySmokeInstrumentation`.
On Android 13+ a test emulator needs notification permission before this native
smoke test; normal users grant it through the in-app opt-in flow.
