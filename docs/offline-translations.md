# Offline repository translations

## Maayong Balita Biblia (1999)

In v0.7.1, choose **Download MBBCEB99**, then **Use MBBCEB99** in Bible
translations. The initial 5.3 MB XML download contains 66 books and 1,189
chapters. Reading, search and annotations then work locally.

The supplied Cebuano1999Bible.xml is pinned to commit
`d68d65dd9ac87e53c759f1a4e649bbc1c1babd49` with SHA-256
`5237563acad9545e6f42dee7ae9996800c9b2dd811862e7aa7ba2cf006ff2bc5`.
It has 30,748 numbered entries, including 30,557 nonempty passages and 191
blank entries. Consecutive blank continuations extend the preceding passage,
for example Genesis 6:1–2. Known textual omissions remain gaps, as do absent
numbered elements. No replacement Scripture wording is invented.

The importer validates numbering, chapter counts, entry totals and integrity
before installation. It rejects DTD/entity declarations and nested verse markup.
Publisher copyright and source attribution remain in Source & license.
User confirmation of merged numbering establishes a technical interpretation
of this file; it does not establish redistribution permission.

## NIV and NLT

In v0.7.0, open Bible translations, choose **Download NIV** or **Download NLT**,
then **Use NIV/NLT**. Internet is needed for the initial download, approximately
4 MB per file. All 66 books and 1,189 chapter containers are installed in local
storage, using the same reader and offline search as other downloaded editions.
The KJV keeps its existing verified eBible.org source.

The files come from the owner's `jhombalz/selah_translation` repository, pinned
to commit `878cdb6aa1dc2764f30b0e6f210cb26574bac799`. Every download checks its
SHA-256, canonical book identifiers/order, chapter counts, verse data and total
entry count before installation. Interrupted, altered or invalid downloads do
not replace installed data. A source update needs an updated pin/hash in the app.

| Edition | Source bytes | SHA-256 |
| --- | ---: | --- |
| NIV | 3,973,089 | `67899d361785d8b341c05d82e07f39c4d3e0d3b9fb3c5609b73cdefb74a589ab` |
| NLT | 4,147,833 | `cab9ee2ff083fd17411a30bebbb47afa02998f1a31be6d0fad844f9153c92829` |

## Known source limitations

The supplied JSON arrays omit some traditional verse numbers. The importer
preserves those gaps instead of shifting later verses, so bookmarks and notes
keep their Scripture references. Third John and Revelation retain the source's
modern verse numbering.

The supplied NLT Numbers 1–2 data is incomplete: table entries and some introductory
wording were lost in the original extraction. Numbers 1:22–43 is absent; Numbers
2 also omits table entries. The app preserves the available text and correct
verse ranges, displays a source warning, and never fills gaps with another
translation or invented wording. A corrected NLT source is required to resolve
these omissions. This is a source-file issue, not an offline download failure.

The repository is a user-supplied source. File availability does not grant
publisher rights, and NIV/NLT have not become public domain. Copyright and source
notices remain under Source & license and the reader's copyright dialog.

## Migration and daily verses

The old online NIV/NLT reader and API client are removed. Old chapter caches are
cleared; notes, highlights, bookmarks, history and progress remain. Previously
selected NIV/NLT editions need one full download. Until then the app labels the
bundled fallback and tells the user to download the desired edition. Restored
backups keep their translation selection when that edition is installed.

The Android build no longer needs or embeds `API_BIBLE_KEY`. The ignored local
secrets file can remain on the developer's PC but is not used by the build.
There is no API.Bible 30-day cache expiry for these repository downloads.

The daily reference refreshes from the project's `web/daily-verses.json` feed.
The feed contains references, not Scripture or credentials. It may feature a
curated passage for a calendar date; otherwise its 80 references rotate daily.
Network failures use the local curated list. Verse wording always comes from
the selected installed edition, so daily verses also work completely offline.
No Bible API requests are made. GitHub Pages deployment remains unchanged.
