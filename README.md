# SELAH

Pause. Reflect. Grow.

[Download SELAH Android v0.7.1](https://github.com/jhombalz/selah/releases/download/v0.7.1/selah-v0.7.1-android.apk)
— universal release-mode APK, signed with the current development key for
personal testing. Install over the previous APK to keep local data.

Version 0.7.1 adds **Maayong Balita Biblia (1999), MBBCEB99** as a one-time
offline download under Bible translations. Download it, then choose Use MBBCEB99.
Merged passages such as Genesis 6:1–2 retain their full reference ranges;
known omitted verses and missing source entries remain gaps. Copyright and
source notices are retained. GitHub Pages is unchanged.

Version 0.7.0 replaces API-backed NIV/NLT with one-time offline downloads from
the owner's translation repository. Select Download NIV/NLT, then Use NIV/NLT.
Reading, chapter navigation, search and personal annotations work locally, with
no Bible API key or 30-day API cache expiry. The daily curated reference refreshes
from an online feed and falls back to the local rotation without internet.
The supplied NLT file omits table content in Numbers 1–2; these gaps are marked
in the reader and download card. See [offline translation guide](docs/offline-translations.md).

Version 0.6.4 uses one responsive book/chapter picker for all editions, including
NIV/NLT. New Testament keeps Gospels and History as separate categories. History
contains History of Jesus (the four Gospels) and History of the Church (Acts).
The Gospel books are intentionally available in both navigation locations.

Version 0.6.3 shortens the navigation label to Devotion and gives NIV/NLT the
shared reader header, AA font settings, rounded mobile chapter dock and desktop
edge arrows. Online-reader menus hide on deliberate scrolling and stay hidden
across chapter changes until returning to the top. Refresh and cache controls
are available inside AA. Existing data and licensed-content rules are preserved.

Version 0.6.2 groups New Testament History into Jesus (Gospels) and Church (Acts),
rotates 80 curated daily reflection passages, and adds Time with God to the main
navigation. Search opens from the Bible toolbar. Home uses a dedicated clamped
scroll view, and tapping Home again returns to the top. Assessment choices save
and advance automatically; the last answer submits, without a question grid.

Version 0.6.1 makes NIV/NLT selectable translations in the Bible tab and uses the
chosen edition for daily verses, Saved previews, sharing and reflection sessions.
The Android audio notification icon is retained in release builds, fixing a
missing-icon crash when WEB/BSB starts playback. Bible parsing and source
formatting run off the UI thread to reduce startup stalls.

Version 0.6.0 adds Android-only NIV and NLT chapter reading through API.Bible.
Open Bible translations and choose Use NIV or Use NLT. Opened chapters are
cached for up to 30 days, with a limit of 60 recent chapters; this is not a full
offline download. Personal notes, highlights and bookmarks use shared Scripture
references. NIV/NLT audio and TTS remain disabled pending permission.
GitHub Pages remains on v0.5.0. See [Android online editions](docs/android-online-editions.md).

Version 0.5.0 refreshes the reader toolbar and adds desktop edge navigation,
offline source headings, BSB section references and publisher footnotes, KJV
red-letter text and source-marked italic words. AA opens reading preferences,
including optional flowing paragraphs with verse selection. Existing downloaded
editions pick up matching bundled metadata automatically.
See [reader formatting guide](docs/reader-formatting.md).

Version 0.4.1 adds optional Cebuano ULB and KJV offline downloads, isolates
Home scroll state, and enables Android background audio with a media
notification and lock-screen controls. WEB and BSB automatically continue
across chapters when the phone is locked. Cebuano and KJV remain text-only.
See [background audio and translation guide](docs/background-audio.md).

Version 0.4.0 adds Bible → tap a verse → Study notes, with English Tyndale Open
Study Notes, selected-passage and chapter views, source/license links and an
offline cache of up to 100 opened chapters. Internet is needed the first time
a chapter is opened. Commentary is clearly separate from Scripture and personal
writing. See [study-notes guide](docs/study-notes.md).

Version 0.3.2 keeps reading menus hidden across chapter changes until scrolling
back to the top, unifies app dialogs with rounded sheet styling, and refreshes
assessment cards and progress. A running-assessment banner stays visible across
all app pages and opens the current attempt. Android also shows a countdown
notification and a time-expired notification, with notification permission.
System battery restrictions can delay the expiry alert. Browser push is not included.

Version 0.3.1 refreshes My time with God with a welcoming sage card and clearer
saved entries. Sharing opens a rounded bottom sheet with a scrollable preview
and fixed Copy/Share actions; private writing remains unchecked by default.

Version 0.3.0 adds Home → Bible assessments: five English levels, 20 questions
each, 80% passing, sequential unlocks and a 24-hour retake wait per level from
submission. Timers cannot pause; answers and deadlines persist locally. Results
show grades and topic totals without revealing correct choices. Assessment data
stays on this installation and is separate from Bible backups.
See [assessment guide](docs/bible-assessments.md).

Version 0.2.3 adds Android reflection dictation under My time with God. Choose
Speak my reflection, select a language, review/edit the recognized words, then
add them after your existing reflection. Device speech services may send audio
online; language and offline support depend on the installed provider. SELAH
does not record or retain audio. This release also applies the ivory/sage light
and charcoal dark palettes and deliberate-scroll thresholds for reader menus.

Version 0.2.2 adds separate offline morning and bedtime reading reminders under
My time with God, each with its own switch and local time. Tap a reminder to
open the Bible. Existing daily reminders keep their time as the morning reminder.

Version 0.2.1 adds automatic audio continuation across chapters and books for
WEB and BSB, with the reader following the active chapter. Playback stops at
the end of Scripture. Streaming audio requires internet.

SELAH uses an original open-book-and-sun mark in forest green, warm cream and
gold. The header wordmark uses the bundled Source Serif 4 font. The vector
source is `web/selah-mark.svg`; the matching Flutter mark is drawn locally and
the browser favicon and installation icons are included in the web release.

A Flutter Bible application for Android, with web and iOS project scaffolding.
The current reader includes an English interface, light/dark themes, adjustable
text, and the complete Biblica® Open Ang Pulong sa Dios™ Cebuano Bible:
66 books and 1,189 chapters, with book/chapter selection and chapter navigation.
Home opens first with Continue Reading. Bookmarks, notes, highlights, reading
preferences, last chapter/scroll position, completion, and history are saved locally.
Chapter completion is explicit; merely opening a chapter does not count as reading it.
The reader has a rounded bottom pill combining previous/next arrows and the
current book/chapter, plus an AA text-size panel with saved preferences. The
Books picker opens full-screen on phones and in a centered dialog on large
screens, highlights/scrolls to the current book, and shows a chapter grid after
book selection. Back/cancel preserves the current passage.
Books are grouped by Old/New Testament, then by Law, History, Poetry & Wisdom,
Major/Minor Prophets, Gospels, Pauline/General Letters, and Prophecy. Categories
expand independently. Book search spans both testaments and supports English
and Cebuano names.
While reading, scrolling down hides the toolbar and navigation menu to enlarge
the reading area; scrolling up restores them. The chapter pill stays available.
Opening a chapter restores the controls. Programmatic verse jumps do not hide them.
Long-press a verse and drag up or down to select a passage within its chapter.
The selected range is highlighted while dragging; holding near a reading edge
scrolls to extend it. Release to bookmark, write a reflection, or highlight the
range. Touch and held mouse gestures are supported. Recoloring/removing part of
a highlight preserves its color outside the selected verses.
In the reader, notes appear as small tappable icons beside Scripture instead
of inline reflection text. A range note opens its original range when tapped;
overlapping notes can be chosen from the verse actions.
Scripture uses locally bundled Source Serif 4 (regular/bold/italic) from Adobe,
licensed under SIL OFL 1.1. The license is available in Settings → Font & app
licenses. No online font service is required when reading.

Offline search supports whole words, exact phrases, book filters, and Cebuano or
English references (`Juan 3:16`, `John 3:16–18`, `Genesis 1`). Quoted queries also
use phrase mode. Case and punctuation are ignored. Results open their chapter
at the selected passage, with a visible border around the target verse.
Combined source verse ranges are preserved. Results are shown 50 at a time.
Queries/filters are retained across tab changes for the current session.

Bible text is bundled locally; chapters do not require an API. Release web builds
prepared with `tools/build-web.cmd` cache the reader, bundled Bible, fonts and
SQLite runtime for offline reopening after initial online preparation. HTTPS
(or localhost) is required. Browser storage/cache can still be cleared or evicted.
Mobile offline behavior still requires device testing.

## My time with God

Home and Saved now open a local guided journey: **Pause → Read → Reflect → Pray
→ Live**. Start with your current chapter or choose Anxiety, Stress, Grief,
Loneliness, or Joy. Fifteen original English passage guides provide context,
a reflection question, a suggested prayer, and a practical invitation. They
open Scripture in the selected Bible rather than substituting another edition.
Every step can be skipped. Drafts autosave, and completing a session never
automatically completes a Bible chapter or measures faith.

The prayer journal supports titles, categories, personal statuses, dated updates,
and unfinished update drafts. Session reflections remain separate from verse
notes. Backup format v2 includes sessions and prayers and still imports older
v1 backups. Schema v4 upgrades without resetting existing records.

Android reminders are opt-in, use generic notification text, and may be delayed
by Android battery management. Sharing previews exactly which Scripture,
reflection, prayer, or response is selected; private writing starts unchecked.
Use the share button in a session or Share passage in verse actions.
No accounts or AI API are required. See [the guided journey guide](docs/guided-journey.md)
for privacy, content review, setup, and verification details.

## Translations

Use the reader's edition button or Settings → Bible translations. Cebuano is
always bundled. WEB, BSB, Tagalog ULB and ASV can be downloaded, selected, searched offline, and
removed. Removing a selected download switches back to Cebuano and preserves
notes, bookmarks, highlights, and progress. Combined verse references remain
associated across editions; notes retain their original creation edition.
Language filters make English and Tagalog editions easy to find. BSB is public
domain; ULB is © 2018 Door43 World Missions Community, CC BY-SA 4.0. Full ULB
credits are bundled locally and retained in the installed edition's license.

Home includes a Verse of the Day in the selected edition. When online,
[bible-api.com](https://bible-api.com/) supplies a random reference from the
whole Bible; SELAH displays the text from the selected local translation.
Without internet, a daily random selection draws from all locally available
verses across all 66 books. The day's choice is cached locally, including an
online choice for later offline use, and resets at local midnight. After an
offline start, Home retries the online source on resume or once a minute.
Read in context opens the exact passage. Requests carry no notes or reading
history; the external service receives standard network request information.

Downloads show progress, allow cancellation, and validate the ZIP, pinned text
checksum, and complete canon before installation. A failed download does not
replace an installed edition. Browser downloads are same-origin packages under
`web/translations`; Android/iOS download the vetted eBible packages directly.
The existing user database upgrades non-destructively to schema version 4.
The daily verse cache is separate from exported user annotations.

## Run locally

Recorded chapter audio is available when WEB or BSB is selected: use the Play/Pause
button beside the chapter bar. It streams David Williams' public-domain WEB
recording or Bob Souer's CC0 BSB narration and requires internet. Changing chapters/editions or leaving Read
stops playback; a new chapter never autoplays. OCCB, Tagalog ULB and ASV do not substitute
another translation's recording. Settings → Audio narration shows attribution
and the note that this older WEB recording can differ from the updated text.
Audio does not mark chapters completed and has no offline download mode.
Follow audio scrolls through the Scripture portion using playback position and
duration. This is an approximate chapter-level aid, not verified verse timing.
Manual scrolling suspends following; Resume auto-scroll beside the player
continues it. Auto-scroll can be disabled there or in Settings → Follow audio.
The preference is saved locally and included in backups. Pausing, buffering,
errors, chapter changes and leaving Read stop automatic movement.

The project-local Flutter SDK is installed under `.tools/flutter` and excluded
from version control. In PowerShell, from this directory:

```powershell
.\.tools\flutter\bin\flutter.bat run -d chrome
```

## Verification

Flutter 3.47.9 / Dart 3.13.7: 63 tests pass, including guided-session navigation,
journal persistence, legacy and journal backup restoration, repeat avoidance,
private share previews, and audio catalog
coverage, play/pause/replay, stale-load cancellation and retries, backup validation,
merge/replace conflict handling, transaction rollback and confirmation, touch/mouse range
selection, autoscroll and partial highlight editing, complete WEB/BSB/ULB/ASV package
validation, database migration, persistence and removal safety, Books picker navigation, offline search/reference
matching, exact result navigation, native
SQLite close/reopen persistence and Home/Continue Reading. An isolated Chrome
check also verified both new editions, annotations, offline reference search and
backup restoration across a full browser process restart. Responsive checks at
320, 768 and 1440 pixels with 150% interface text pass. BSB streaming was checked
in Chrome. Offline Home and Scripture reopening were checked in release Chrome
with the network disabled and HTTP cache disabled.
The release web build passes (with an existing Cupertino icon-font warning).
Android debug/release builds and the guided reading flow are verified on an
Android 12 emulator. Native reminder enable/schedule/notification/disable and
the Android share chooser are checked separately. iOS builds remain unverified.
Compiled web files are in `build/web`.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the staged implementation plan and
current limitations. Broader real-device validation remains pending.

Build a web release with offline preparation:

```powershell
.\tools\build-web.cmd
```

The post-build step generates a versioned offline worker from the built files;
deploy the whole `build/web` directory. Translation ZIPs and remote audio are
excluded from precaching. A first online visit must finish preparing the cache.
Updates activate after existing app tabs close; user data remains in Drift.
The development server does not provide offline reopening.

## GitHub Pages

Live app: https://jhombalz.github.io/selah/

The Pages workflow builds and tests the app on pushes to `main`, then deploys
the web release with `/selah/` as its base path and offline preparation enabled.
Repository Settings → Pages uses GitHub Actions as the deployment source.
To reproduce the Pages build locally:

```powershell
.\tools\build-web.cmd --base-href /selah/
```

Browser data is separate for localhost and the published site. Use Backup &
restore to move your notes, bookmarks and reading progress; download optional
translations again on the published site.

## Local storage

`lib/data/user_database.dart` owns a versioned Drift schema with preferences,
annotations (including source translation), and chapter history/completion.
Android/iOS use local SQLite; web uses the supported persistent OPFS/IndexedDB
backend selected by Drift. In-memory browser fallback is rejected explicitly.
Browser data belongs to its profile and origin (scheme, host, port). Clearing
site data deletes it. Flutter's automated Chrome launch can use a temporary
profile; use a normal browser profile on the same URL for ongoing personal use.
Settings → Backup & restore exports a versioned, checksum-protected JSON file
containing user annotations (including ranges and note provenance), preferences,
chapter history and completion. Bible datasets are excluded. Files are unencrypted
and limited to 10 MB; import validates the format, version, checksum, references,
types and bounds before offering a preview.

Merge keeps existing notes/settings and overlapping highlight colors, combines
bookmarks/completed chapters and keeps the latest chapter visit date. Repeated
merges are idempotent. Replace requires confirmation and removes user records
absent from the backup. Both modes preserve installed Bible datasets and run in
one transaction. Missing/corrupt selected editions fall back to the bundled Bible.
Web export initiates a browser download; native export uses the file picker.

## Android Focus Mode

Choose daily reading minutes and apps to pause in **Settings → Focus Mode**.
Selected apps display a reading gate until the daily goal is complete. Setup
requires the user's Android accessibility approval. See
[Android Focus Mode](docs/android-focus-mode.md) for setup, privacy, behavior,
and verification details. This feature is Android-only.

## Bible source and license

The specifically open edition is distributed under CC BY-SA 4.0. Complete
attribution is in `assets/bible/LICENSE.txt` and available in the app's settings.
`assets/bible/provenance.json` records source URLs, counts, and SHA-256 hashes.
Scripture wording is unchanged; source VPL text omits headings and footnotes.
Combined verse-range labels are preserved from the corresponding USFX source.

To reproduce the import, download and extract the provenance-listed VPL archive
to `.tools/bible-source` and USFX archive to `.tools/bible-usfx`, save the source
copyright page as `assets/bible/copyright.html`, then run:

```powershell
node tools/import-bible.cjs
```
