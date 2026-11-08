# SELAH: Scripture, prayer, and daily life

Status: proposed development phases; no new application features are implemented
by this document. The owner requested this roadmap after reviewing
`bibleafeature.md` (Mood & Circumstance Mapping). That document is a proposal to
evaluate, not an instruction to implement every feature or adopt its claims.

## Product direction

Help a reader move from Scripture to reflection, prayer, and a practical response:

**Pause → Read → Reflect → Pray → Live**

Keep ordinary Bible reading one tap away. Guided sessions and emotional check-ins
are optional. Completion, minutes, and streaks do not measure faith or closeness
to God. Focus Mode supports a voluntary habit; it must not make Scripture feel
like a fee for opening another app.

The audience remains the owner and friends in the Philippines: Android first,
English interface, Cebuano Scripture prioritized, offline access, and local data
without accounts. Cebuano reflection/prayer content can follow once reviewed.

## Assessment of the supplied feature document

| Proposal | Fit for SELAH | Decision |
| --- | --- | --- |
| Gentle emotional check-in | Strong, if optional and easy to skip | Phase 9; do not interrupt every app opening |
| Anxiety, stress, grief, loneliness, joy | Useful starting themes | Phase 9; avoid diagnoses and promises of relief |
| Life circumstances such as family conflict or waiting | Useful but needs careful passage selection | Expand after the initial five themes |
| Scripture with surrounding context | Essential | Begin in Phase 8; open the actual passage in the existing reader |
| Short devotional and prayer prompt | Fits the guided journey | Use original or licensed, reviewed content; distinguish commentary from Scripture |
| "Spiritual Prescription" wording | Overstates the app's authority | Use "Scripture for this season" or "What are you carrying today?" |
| Manually curated 100-verse database | Sensible later scale; too much initial review work | Pilot 15–25 contextual passage cards, then expand after feedback |
| Different passages when a theme is selected repeatedly | Strong fit, works locally | Phase 10; move this ahead of AI |
| API routing and remote personalization engine | Unnecessary for the initial feature | Match bundled tags and references on-device |
| Semantic search/freeform NLP | Potentially useful, adds complexity | Phase 13 exploration; first use theme chips, synonyms, and existing search |
| AI devotional/prayer generation | Needs an editorial and privacy strategy | Defer; it is not required for the initial experience |
| Cinematic devotional audio | Secondary to useful content | Optional Phase 11, with licensed/original recordings and transcripts |
| Private sharing | Appropriate when explicitly chosen | Phase 12, initially through the phone's share sheet |
| Family feeds or private groups | Possible future direction | Defer accounts, sync, permissions, and moderation until separately scoped |
| Global anonymous prayer wall | Poor fit for the current local-only app | Exclude from the initial roadmap; anonymity, moderation, and abuse handling need a separate product design |
| Repeated severe moods trigger crisis escalation | Do not infer a crisis from a mood history | Offer optional access to support; do not diagnose or assign risk from check-in frequency |
| DAU/MAU target above 45% | Not evidence of spiritual usefulness | Treat the document's industry-benchmark claim as unverified; do not adopt it as a target |

The document's opening comparison also does not describe SELAH's current daily
verse: SELAH already selects a random online reference with a whole-Bible local
fallback. A random daily verse and a curated, theme-related passage serve
different purposes and should remain separate entry points.

## Phase 8 — My time with God: a complete guided session

Priority: next implementation phase.

Add a Home entry labeled **My time with God** alongside Continue Reading.
Begin with the reader's current chapter rather than requiring an emotional
check-in or a new reading-plan system.

1. Pause: a short optional invitation to become still and pray for understanding.
2. Read: open the existing Bible reader at the chosen passage in the selected
   translation. Preserve normal chapter navigation and annotations.
3. Reflect: offer one general question, such as "What does this passage reveal
   about God?" The reader may write a response or skip it.
4. Pray: offer an editable prompt and a private place to write a prayer.
5. Live: let the reader choose one small response, or leave it blank.

Save drafts locally and resume an unfinished session. Reuse the existing note
editor interaction where helpful, but store session reflections, prayers, and
actions separately from verse annotations. Saving a session must not create
repeated verse notes or automatically mark a chapter read.

Acceptance: the complete flow works offline; every step is skippable; drafts
survive a restart; selected translation/reference remain accurate; ordinary
Bible reading remains directly accessible; the session appears in backup and
restore with backward compatibility for existing backups. Users can delete it.
Focus Mode continues to count only its existing eligible Bible-reader time;
time spent in reflection forms or prayer pages does not silently earn credit.

## Phase 9 — Scripture for what you are carrying

Add an optional **What are you carrying today?** entry. Start with Anxiety,
Stress, Grief, Loneliness, and Joy, plus Skip/Continue Reading. Do not force a
choice or treat it as a clinical assessment.

Bundle 15–25 reviewed passage cards (approximately 3–5 per theme). Each card
contains a canonical passage reference, theme tags, a short contextual
introduction, a reflection question, a prayer prompt, and an optional action
invitation. It can open a Phase 8 session.

Resolve Scripture text through SELAH's selected local Bible. Do not duplicate
English Scripture as a substitute for Cebuano or mix translations without a
label. If a focal verse is shown, make its surrounding passage directly
available. Separate original editorial text from the Bible text visually.

Editorial review is a delivery dependency: check passage context, language,
content rights, and suitability for the broad Christian audience before
shipping a card. Avoid interpreting ordinary hardship as evidence of weak
faith. Do not promise that a passage or session will cure a condition. No AI
or network service is necessary for this phase.

Acceptance: the initial five themes work offline; all references resolve;
every card has recorded author/source/license and review status; the whole
passage is available; check-ins are private and not shared automatically.
Do not persist mood selections by default; repeat avoidance can record content
IDs without building a mood history.

## Phase 10 — Gentle continuity and a private prayer journal

Add recent guided sessions and private prayers, with optional categories such
as gratitude, request, lament, and waiting. Let the reader record an update or
mark a prayer "Answered" or "Still praying" themselves. The app must not claim
to determine whether or how God answered a prayer.

Avoid recently shown passage-card IDs when the reader selects a theme again.
After all suitable cards have been seen, recycle the least recently shown
instead of hiding content or generating unreviewed material.

Offer a gentle follow-up on the reader's chosen action. Optional reminders
must be opt-in, and lock-screen notification text should not reveal prayer or
emotional content. Extend export, restore, and deletion to the new records.
Do not describe the journal as encrypted until encryption is implemented;
existing exports are unencrypted.

Acceptance: repeat avoidance works without internet; prayer updates and drafts
persist; backup round trips preserve the records; notification permissions
and scheduling are tested on Android; no guilt-based streak warnings.

## Phase 11 — Cebuano depth and content expansion

Review and introduce Cebuano reflection questions, contextual introductions,
and prayer prompts. Scripture continues to use the licensed selected edition.
Expand toward 100 reviewed cards when there is sufficient useful variety,
including waiting, decisions, family relationships, gratitude, and forgiveness.

Add short book-based reading journeys so readers also encounter passages they
would not choose from their current mood. They complement contextual theme
cards and the existing random Verse of the Day.

Optional original/licensed devotional audio follows content review, with clear
language labels, transcripts, and honest availability. Do not substitute an
English Bible recording for a Cebuano edition's text.

Acceptance: content and translation rights are documented; reviewed Cebuano
wording is understandable to the intended readers; packaged text works offline;
any streamed audio clearly requires internet.

## Phase 12 — Sharing chosen by the reader

Start with the platform share sheet: the reader chooses a passage or their own
reflection, previews exactly what will be shared, and sends it through an app
they choose. Nothing is posted automatically. Keep mood history and private
prayers out of the share payload unless the reader explicitly includes them.
Retain required translation attribution and applicable sharing limits.

Family groups, accounts, cloud sync, and prayer feeds are separate later
projects. They are not prerequisites for useful sharing with friends.

## Phase 13 — Evaluate advanced features after the pilot

Consider freeform theme search, on-device semantic matching, optional sync, or
private group features only when feedback identifies a concrete need. Start
with ordinary theme synonyms and reference search before vector search.

AI-generated spiritual content is deferred. Any future proposal needs source
grounding, clear authorship labels, editorial boundaries, and a decision about
whether private journal text ever leaves the device. Do not present generated
words as a message from God or allow unreviewed material to overwrite Scripture.

## Implementation approach

- Keep content in a versioned bundled catalog initially. Store canonical
  references, tags, editorial text, language, source/license, and review status.
  Validate every reference against the bundled canon during checks.
- Keep personal session/prayer/action records in Drift, separate from content
  catalogs, verse annotations, daily-verse cache, and Android Focus preferences.
- Use ordinary SQLite tables and a content/tag join table if tags are stored in
  SQL. The document's `secondary_tags TEXT[]` declaration is not a usable
  relational tag collection for this schema; do not copy it as-is. Drop the
  subjective `theological_weight` score until a real selection need exists.
- Use non-destructive database migrations and a versioned backup extension.
  Older annotation backups must remain importable. Do not silently omit private
  journal records from a backup described as containing them.
- Keep this modular: catalog selection, session storage, guided-session UI,
  and reminders are separate from the large reader widget in `main.dart`.
- If support resources are added, provide an optional Help and support entry
  and verify relevant local contacts at implementation time. Mood choices alone
  must not trigger diagnosis, risk scoring, or involuntary sharing.

## Pilot and evidence of usefulness

After Phase 8, invite the owner and a small group of willing friends to try the
flow for a week. Ask whether it helped them understand the passage, pray
honestly, and choose a practical response. Ask what felt distracting or forced.
Include readers who prefer to skip the guided flow.

Use voluntary feedback first. If metrics are introduced, define the purpose
and consent before adding analytics. Local counts of resumed sessions or used
prompts can identify friction, but neither usage nor minutes can establish
spiritual growth. Do not upload moods, prayers, notes, or journal contents to
measure retention.

Build Phase 8 first, pilot it, then refine before adding Phase 9.
