# Tagalog MBB05

The new Tagalog download is Magandang Balita Biblia (2005). Choose Download
MBB05, then Use MBB05. A previously installed Tagalog ULB is retained as a
previous edition; it is not relabeled, deleted, or offered to new installations.
Canonical bookmarks, notes and highlights continue to work across editions.

## Text source

- Repository: https://github.com/develop4God/bible_versions
- Commit: `6abc60ede9177e6cbbdb1842b785e4edb1cafbec`
- File: `fil/MBB05_fil.SQLite3.gz` (2,379,823 bytes)
- SHA-256: `440b628b0df0cf160820750242ad288680a388413a437373c9dcd860da6f24f1`
- Source metadata identifies Magandang Balita Biblia, 2005, © 2005 Philippine
  Bible Society, with YouVersion version 144 named as its origin.

The repository's MIT license covers its tooling, not Bible texts. Copyright
and origin notices remain in the app; repository availability does not establish
publisher redistribution permission.

The source contains additional books. The importer explicitly selects SELAH's
66-book canon and 1,189 chapters: 31,046 numbered entries, including 517 blank
continuations/omissions and 30,529 nonempty passages. It preserves merged ranges
such as Matthew 2:9–10, and keeps known textual omissions as reference gaps.
Footnote-link markup is removed; poetry, table contents and Scripture wording
are retained. Additional books and Psalm 151 are excluded from the selected canon.

Downloads are hash-checked before gzip decoding, then read through a temporary
in-memory SQLite filesystem in read-only/query-only mode. Schema, edition,
numbering, canonical coverage and entry counts are validated before the normal
local translation installation. No publisher API key or backend is used.
Bible text stays out of personal-data backups.

## Audio

`https://archive.org/details/tagalogbibleaudio` has 260 New Testament MP3s with
the `N2TGLMBB` identifier, attributed to Faith Comes By Hearing. Explicit chapter
mappings are stored in `assets/audio/mbb05.json`. Generate with
`node tools/generate-mbb-audio.cjs --tagalog`.

The uploader labels the archive CC BY-NC-ND 3.0 Philippines. This label has not
been independently verified with the rights holder. Text/audio word-for-word
alignment is not independently verified, and no verse timestamps are supplied.
Recordings stream online. Old Testament reading uses Filipino/Tagalog TTS.
NLT keeps English TTS; Cebuano and English recorded sources are unchanged.

## Web runtime

The importer uses the official sqlite3.dart **3.5.2** WASM release as a separate
`web/sqlite3_import.wasm`; the existing Drift database runtime is unchanged.
Release: https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.5.2

Binary SHA-256:
`13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4`

Its license is included in `web/sqlite3_import.LICENSE.txt`, and the offline
preparation script caches the runtime. Update the dependency and WASM binary
together if the SQLite package is upgraded.
