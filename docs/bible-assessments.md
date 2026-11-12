# Bible assessments

Available from Home → Bible assessments in SELAH v0.3.0. No account, AI service,
or internet connection is needed. The bank contains 100 original English
multiple-choice questions, 20 per level, with four choices and one correct choice.
Question and choice order are shuffled for each attempt and saved for resuming.

| Level | Name | Time limit |
| --- | --- | --- |
| 1 | Beginner | 180 minutes |
| 2 | Elementary | 150 minutes |
| 3 | Intermediate | 120 minutes |
| 4 | Advanced | 90 minutes |
| 5 | In-depth | 60 minutes |

Each question is worth one point. Passing requires 16/20 (80%). Level 1 is
available initially; each next level unlocks after passing its predecessor.
An earlier pass remains valid even if a later retake scores lower.

Before starting, a warning explains that the timer cannot be paused. The saved
deadline continues when leaving the screen, switching apps, closing the app,
or restarting the device. On reopening or resuming, expired attempts are graded
using their saved answers, with the deadline recorded as the submission time.
No background notification or continuously running Android service is required.

Since v0.3.2, a compact running-assessment banner appears across app pages and
dialogs. Tap Resume to return to the saved attempt. The banner disappears when
the assessment is submitted or expires, without resetting the current page.
Android can show an ongoing system countdown notification that remains visible
in the background and opens the attempt when tapped. Notification permission is
requested before starting; denying it does not prevent the assessment. At expiry,
an inexact alarm changes the notification to "Assessment time is up". Android
battery restrictions, force-stop and manufacturer settings can delay or prevent
the expiry notification; the saved deadline remains authoritative. SELAH does
not run a foreground service. Browser push notifications are not implemented.

Since v0.6.2, tapping an answer saves it and moves to the next unanswered question
in one transaction. Answering the final question submits automatically and starts
the 24-hour retake wait. The start warning explains this. There is no numbered
question grid, review flag control, or manual submission button. Choose carefully
before tapping: the normal flow does not return to previous questions. Older
attempts keep their saved choices and advance to their remaining questions.
After submission, choices cannot be edited. At time expiry, unanswered questions
are incorrect. Storage errors show a retry message while the timer keeps running.

Results show Passed/Failed, total score, percentage and topic totals. They do
not reveal correct choices, individual-question correctness or an answer review.
Retaking the same level is allowed after 24 hours from its latest submission,
not at midnight and not from its start time. A newly unlocked level can be
started immediately, but only one attempt can be active at a time.

Assessment records are stored separately on this installation. Existing Bible
backups do not export, restore, or reset assessment attempts and cooldowns.
Clearing app/site data or reinstalling without preserved data loses this progress.
Device-local timing and the embedded answer key are not secure examination
controls: clock changes across restarts, app data manipulation or inspection can
bypass them. During an open assessment screen, elapsed time prevents a backward
clock adjustment from restoring time. This is a personal learning feature.

The question bank is an initial English editorial set with internal Scripture
references validated against the bundled 66-book Bible. It has not received an
independent pastoral/editorial review. Historical grades use bank version 1;
changing existing keys/questions requires preserving that version for attempts.
Grades measure knowledge of these questions, not faith, spiritual worth, or
closeness to God. No AI writes questions or grades attempts.
