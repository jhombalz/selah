# SELAH

Pause. Reflect. Grow.

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

## Translations

Use the reader's edition button or Settings → Bible translations. Cebuano is
always bundled. WEB, BSB, Tagalog ULB and ASV can be downloaded, selected, searched offline, and
removed. Removing a selected download switches back to Cebuano and preserves
notes, bookmarks, highlights, and progress. Combined verse references remain
associated across editions; notes retain their original creation edition.
Language filters make English and Tagalog editions easy to find. BSB is public
domain; ULB is © 2018 Door43 World Missions Community, CC BY-SA 4.0. Full ULB
credits are bundled locally and retained in the installed edition's license.

Home includes a Verse of the Day in the selected edition, rotating through 31
passages by local calendar date. Read in context opens its exact passage.

Downloads show progress, allow cancellation, and validate the ZIP, pinned text
checksum, and complete canon before installation. A failed download does not
replace an installed edition. Browser downloads are same-origin packages under
`web/translations`; Android/iOS download the vetted eBible packages directly.
The existing user database upgrades non-destructively to schema version 2.

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

Flutter 3.47.9 / Dart 3.13.7: 48 tests pass, including audio catalog
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
Android and iOS builds are not verified.
Compiled web files are in `build/web`.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the staged implementation plan and
current limitations. Native device validation remains pending.

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
