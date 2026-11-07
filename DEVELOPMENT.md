# SELAH development

## Confirmed scope

Android first; Flutter and Dart; future web and iOS support. English interface.
Primary audience: the owner and friends in the Philippines.
Primary Bible: Biblica Open Ang Pulong sa Dios (Cebuano), using the specifically
open-licensed dataset, not text copied from a different APD edition.
License source: https://ebible.org/cebocb/copyright.htm (CC BY-SA 4.0).
Preserve complete required attribution and license notices when importing it.
No accounts or cloud sync in version one.

## Stages

1. Foundation: responsive reader, forest/cream theme, dark mode, font controls,
   session-only bookmark, highlight, and note interactions. Source created.
2. Project-local Flutter 3.47.9 / Dart 3.13.7 installed in `.tools/flutter`;
   Android/web/iOS platform scaffolding generated. Analyzer and responsive
   phone/desktop navigation smoke test pass.
3. Import and validate the complete licensed Cebuano Bible, its 66-book catalog,
   verse identifiers, notices, and data provenance. Bundle for first-launch offline use.
   Complete: 66 books, 1,189 chapters, 30,552 verse entries (combined ranges
   preserved). Book/chapter selectors and cross-book chapter navigation added.
   Canon integrity, responsive navigation, chapter/bookmark tests and analyzer pass.
4. Add Drift persistence, migrations, resumable reading position, manual chapter
   completion, history, and Scripture-reference-based annotations/ranges.
   Verify supported Drift web persistence before selecting its storage backend.
   Implemented: versioned separate user-data database, persistent verse
   annotations/preferences, last chapter/scroll offset, explicit chapter completion,
   and recent chapter history. Home opens first with Continue Reading.
   Native SQLite close/reopen test and isolated Chrome process-restart persistence
   check pass. Web uses Drift's persistent OPFS/IndexedDB selection and rejects
   in-memory fallback. Long-press-and-drag verse ranges are now supported,
   including reversed selections, source combined verses, and edge autoscroll.
   Recoloring or clearing a subrange preserves highlights outside the selection.
5. Offline search with book filters, phrases, and Scripture-reference lookup.
   Complete for the bundled Cebuano edition: whole-word AND search, punctuation-
   and case-insensitive phrase matching, book filters, Cebuano/English reference
   names and common aliases, chapter/verse/range lookup, paginated results,
   debounced input with stale-query cancellation, and exact verse navigation.
   The search index is built locally in yielding chunks; no API is called.
   Search options survive tab changes during the session. Ten tests pass.
6. Translation downloads, integrity checks, removal, and management. Retain the
   bundled Bible; deleting a translation must not delete user annotations.
   Complete: WEB/ASV package downloads, progress/cancel/retry, ZIP/text integrity
   checks, full canon validation, atomic installation, checksum-verified loading,
   persistent selection, and safe removal. Schema v2 adds a translations table
   without resetting user data. Reader switching follows the current canonical
   passage; annotations overlap source combined ranges and retain note provenance.
   English and Cebuano reference aliases work in each edition. Sixteen tests pass.
7. Versioned export/restore with merge and replace flows; responsive and Android
   offline/persistence/restart checks; release packaging.
   Backup/restore implemented in Settings using unencrypted versioned JSON with
   a payload checksum, bounded file reads, strict schema/reference validation,
   and a preview. Merge preserves local conflicts and is idempotent; Replace
   requires confirmation. Restores are atomic and preserve downloaded Bibles.
   Rollback, conflict resolution, validation and UI confirmation tests pass.
   Native file dialogs still need real-device testing. Android/iOS device checks
   and release packaging remain pending. Release web offline reopening is now
   implemented through `tools/build-web.cmd` and verified in isolated Chrome.

Recorded WEB and BSB chapter audio is implemented with on-demand streaming, play/pause,
replay, load cancellation, and network-error retry. All 1,189 chapter mappings
are checked against the canon. Attribution and the recording/text edition
difference are shown in Settings. No recording has been configured for OCCB,
Tagalog ULB or ASV, and playback never substitutes a different translation.
BSB and Tagalog ULB downloads retain required credits; their full canon, native
SQLite reopen, source-note provenance and backup round trips are tested.
Language filters and large-text layouts at phone/tablet/desktop sizes are checked.
Daily verses rotate offline through 31 passages in the selected translation.
Offline audio, reading plans, devotionals, and sync are deferred. 43 tests pass.

## Current preview limitations

Reader UI update: rounded bottom pill combines previous/book-chapter/next.
Books opens full-screen below 840 px and in a centered dialog above that width.
The current book is highlighted and scrolled into view; selecting a book shows
its chapter grid. Search is available from the Books toolbar. Back/cancel leaves
the current passage unchanged. AA text-size controls remain in the reader toolbar.
43 tests pass, including backup validation/restoration, range gestures, autoscroll, highlight range
editing, Books-to-chapter navigation, and translation flows.

Complete Cebuano Scripture is bundled as a read-only asset. No API is needed
for chapter reading. Source footnotes and noncanonical headings are not included.
User data and downloaded translations are stored locally using Drift.
Release browser offline reopening is verified after initial online cache
preparation (HTTPS or localhost). The build script precaches the app shell,
bundled Bible, fonts and renderer, excluding translation ZIPs and audio.
Browser storage may be cleared or evicted; backups remain important. Development
server offline reopening is unsupported. Mobile offline use needs device testing.
History lists the latest visit per chapter, not a log of every reading session.
No automatic completion is inferred from visiting or scrolling a chapter.

## Local setup

Flutter is installed locally. From this folder:

```powershell
.\.tools\flutter\bin\flutter.bat pub get
.\.tools\flutter\bin\flutter.bat analyze
.\.tools\flutter\bin\flutter.bat test
.\.tools\flutter\bin\flutter.bat run -d chrome
```

iOS builds require macOS and Xcode. Android development requires the Android SDK.
