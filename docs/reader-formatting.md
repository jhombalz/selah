# Reader layout and source formatting

The Bible toolbar has a passage/search field and a separate book picker on the
left. Translation and AA controls remain compact on phones. Desktop layouts
also show audio and reading-layout controls, with previous/next arrows at the
bottom edges of the reading area. Phones retain the bottom chapter/audio dock.
The existing scroll-to-hide reading controls remain in use.

Tap AA (or Reading layout on desktop) to enable **Paragraph reading**, change
text size, or turn **Words of Jesus in red** on/off. The Close control stays
above the scrolling preferences content. Paragraph mode is opt-in and preserves
the current verse layout until enabled. Both preferences are saved locally and
included in user-data backups.

Paragraphs retain verse numbers, verse taps, long-press-and-drag verse selection,
highlights, bookmarks and personal-note icons. Search-result jumps scroll to
the containing paragraph. Audio following remains approximate chapter progress.

## Available edition-specific formatting

| Edition | Included reading metadata |
| --- | --- |
| Bundled OCCB Cebuano | Source section headings and paragraphs |
| BSB | Source headings, paragraphs, publisher footnotes and section cross-references |
| KJV | Source words-of-Jesus markers and paragraph structure; italic display of translator-supplied words marked with square brackets in the verified VPL |
| Other installed editions | Existing text; paragraph mode retains individual verse blocks when source paragraph metadata is unavailable |

Red-letter text is never guessed from quotation marks or copied from another
translation. BSB and Cebuano source data currently lack these markers. Red
uses a darker tone in light mode and a lighter tone in dark mode.

Tap a BSB section reference to open that passage in the selected translation.
The speech-bubble icon opens **Translation footnotes**, separately from personal
notes (sticky-note icon) and Study notes (Tyndale commentary).

## Offline implementation and fidelity

Committed `assets/bible/formatting/*.json` files contain AO Lab structured
metadata for the exact local edition IDs. BSB's section references come from
eBible's published BSB USFM. Files record source URLs and SHA-256 snapshots.
`node tools/generate-reading-format.cjs` regenerates these assets after source
review; normal builds and reading do not contact the sources.

Before applying metadata, the reader compares Scripture wording against the
installed verse, accounting for whitespace and the source paragraph marker.
KJV square brackets are recognized as its VPL formatting convention, not omitted
words. If wording differs, that verse retains its original display and receives
no mismatched formatting. Combined verse ranges remain single annotation targets.
Stored Scripture, search, sharing, user data and download-integrity checks are
preserved. Existing installed translations acquire matching metadata from the
updated app without needing to download their text again.

Formatting coverage is edition-dependent; missing markers are not synthesized.
Licenses and original translation notices remain available under copyright and
translation management. OCCB retains its Biblica CC BY-SA notices; BSB is public
domain, and KJV retains its territorial rights notice.

## Validation

Focused tests verify wording fidelity across complete editions, red-letter
boundaries, mismatched-edition rejection, precise paragraph tap/drag selection,
desktop edge navigation, publisher footnotes, cross-reference jumps and phone
preferences with enlarged system text. Android layout was inspected on the
Small_Phone emulator.
