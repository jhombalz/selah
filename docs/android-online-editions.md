# NIV and NLT on Android

**This online integration was retired in v0.7.0.** Use the
[offline translation guide](offline-translations.md) for current behavior.
The remainder of this document describes older releases; its API-key build
instructions and chapter-expiry rules no longer apply to the current app.

Open Bible translations on the Android release, then choose **Use NIV** or
**Use NLT** under Online translations. The selected edition opens in the normal
Bible tab, with Home, Bible, Devotion, Saved and Settings still available. The
selection survives app restarts. Switching translations keeps the current chapter.
Select a book/chapter, or use the previous and next arrows. Bookmarks,
verse/range notes, highlights and chapter completion use the same Scripture
references as the offline editions. Personal notes retain their source edition.

The chosen edition supplies the daily verse, Home Continue Reading, Saved passage
previews, verse sharing and My time with God sharing. Licensed previews use the
same bounded chapter cache as the reader and include attribution. Missing text
shows an unavailable/retry message; another edition is never substituted under
an NIV/NLT label. Personal notes retain their original translation label.
For NIV/NLT the header's search control offers book/chapter lookup, not an offline edition's
full-text results. Complete full-text search remains available for downloaded
translations. Accounts, web access and NIV/NLT TTS are not part of this update.

Since v0.6.3, NIV/NLT use the shared passage/search header, book picker,
translation selector and AA reading preferences. AA also contains Refresh chapter
and Clear saved online chapters. Unsupported paragraph/red-letter switches are
omitted for these editions. The mobile reader uses the same rounded chapter dock
as offline editions; desktop has the same edge arrows. Deliberate scrolling hides
menus, and changing chapters preserves that state until scrolling back to the top.

Since v0.6.4, book/chapter selection uses the same shared picker for every edition:
full-screen on phones and the styled SELAH dialog on large screens. New Testament
has separate Gospels and History categories. History expands into History of Jesus
(Matthew, Mark, Luke and John) and History of the Church (Acts). Gospel books are
cross-listed for navigation; the Bible's books and progress counts are unchanged.

## Network use and offline copies

- Only the chapter being opened is requested. There is no prefetch or bulk Bible
  download, and a concurrent duplicate request shares the existing request.
- Valid saved chapters open without an API call. At most 60 recently accessed
  NIV/NLT chapters combined are retained.
- Copies expire 30 days after their successful fetch. Expired copies are removed
  and must be fetched again before display. Refresh never resets a timestamp
  unless the provider successfully returns a validated chapter.
- A failed manual refresh can show an unexpired saved copy with an explicit
  status. Missing or expired chapters show an error and Retry, never Scripture
  from another translation.
- Refresh explicitly makes another request. API limits apply across all users
  of the shared key; this is not an unlimited or permanently offline service.
- The overflow menu clears saved NIV/NLT chapters while preserving personal data.

Copyright and API.Bible attribution are shown on each chapter, including saved
copies. Licensed Scripture and API credentials are excluded from personal JSON
backups. Notes, bookmarks, highlights and reading progress remain included.
The cache is private app SQLite storage, separate from installed Bible packages.

NIV/NLT search, recorded audio and TTS are not enabled in this view. TTS requires
publisher permission. The existing offline Bible reader/search/audio remain
available. Reading a loaded chapter counts toward Focus Mode while its page is
visible; loading/error screens, overlaid dialogs, background and locked-screen
time do not count.

## Private build configuration

The shared key is injected into the personal Android build only. Create the
Git-ignored `.tools/android-secrets.json` with this shape:

```json
{"API_BIBLE_KEY":"YOUR_API_BIBLE_KEY"}
```

Run `tools\build-android-personal.cmd`. It creates a release-mode APK with Dart
obfuscation and stores symbol maps under ignored `.tools/android-symbols`.
Keep those maps for debugging. The APK uses the existing development signing
key so it can update previous personal builds without uninstalling them.

The key does not enter committed source, the published web bundle, user settings
or backups. Obfuscation does not make an embedded APK credential secret; an
experienced person can recover it. The shared-key personal build is the user's
chosen compromise. A backend would be required to keep it private from clients.

NIV/NLT cards are Android-only. Unconfigured development builds display disabled
cards; no key is included in ordinary web builds. GitHub Pages remains on its
existing release and receives no NIV/NLT content or key.

This integration reads API.Bible's structured chapter output without HTML
execution, validates edition/chapter/verse identifiers and response bounds,
preserves Scripture wording, and does not transmit personal writing to the API.
