# NIV and NLT on Android

Open Bible translations on the Android release, then choose **Use NIV** or
**Use NLT** under Online translations. The selected edition opens in the normal
Bible tab, with Home, Bible, Search, Saved and Settings still available. The
selection survives app restarts. Switching translations keeps the current chapter.
Select a book/chapter, or use the previous and next arrows. Bookmarks,
verse/range notes, highlights and chapter completion use the same Scripture
references as the offline editions. Personal notes retain their source edition.

The chosen edition supplies the daily verse, Home Continue Reading, Saved passage
previews, verse sharing and My time with God sharing. Licensed previews use the
same bounded chapter cache as the reader and include attribution. Missing text
shows an unavailable/retry message; another edition is never substituted under
an NIV/NLT label. Personal notes retain their original translation label.
For NIV/NLT the Search tab offers book/chapter lookup, not an offline edition's
full-text results. Complete full-text search remains available for downloaded
translations. Accounts, web access and NIV/NLT TTS are not part of this update.

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
