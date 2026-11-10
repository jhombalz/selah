# Study notes

SELAH v0.4.0 adds optional Tyndale Open Study Notes to the Bible reader.
Tap a verse or select a verse range, then choose **Study notes**.

The rounded sheet displays English commentary independently of the selected
Bible translation. **Selected passage** matches notes anchored to the selected
verses, including ranges identified in a note's leading reference. **Whole
chapter** shows the available notes from that chapter. Some passages have no
notes. This first version does not search earlier chapters for overviews whose
ranges begin in a different chapter. No text is invented to fill missing notes.

Notes are authored interpretation, not Scripture. No AI summaries, rewrites or
automatic translations are used. Wording is displayed as supplied by the API's
simplified text endpoint, including original reference prefixes and paragraphs.
Notes may discuss English wording different from the reader's Bible translation.
The source metadata incorrectly labels some English resources as RTL; the sheet
explicitly displays these English notes left to right.

## Sources and permission

- Resource: Tyndale Open Study Notes, Tyndale Open Resources / Tyndale House Publishers.
- Publisher: https://tyndaleopenresources.com/
- License: Creative Commons Attribution-ShareAlike 4.0 International,
  https://creativecommons.org/licenses/by-sa/4.0/
- API documentation: https://bible.helloao.org/docs/reference/commentaries/
- Chapter endpoint: `https://bible.helloao.org/api/c/tyndale/{book}/{chapter}.simple.json`

The sheet identifies the resource and has source/license links. API-provided
license notices and format-conversion notes are retained in cached records and
displayed in **Source & license**. The app requests only this pinned resource
and accepts its expected English/CC BY-SA 4.0 metadata. This feature adds study
notes; it does not add another Bible translation.

## Offline behavior and data

The first opening of a chapter needs internet. The entire returned chapter is
saved separately from personal writing so nearby verse selections can work
offline without another request. The cache keeps up to 100 recently opened
chapters; older copies may be evicted. **Refresh** checks for current content and
falls back to saved notes if offline. **Remove offline copy** deletes only that
commentary chapter; the current sheet can keep displaying its in-memory content.
Commentary caches are not included in personal Bible backups.

The API receives only the requested book and chapter, not reflections, prayers,
highlights or assessment answers. The app uses no API key, account or AI service.
Response source, license, book, chapter, content shape and size are checked.
Notes render as plain selectable text; remote markup/scripts are not executed.
Schema 6 adds a non-destructive cache table. Existing user data and assessments
remain separate and unchanged.
