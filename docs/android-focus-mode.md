# Android Focus Mode

Open **Settings → Focus Mode** in SELAH. Choose a daily reading goal (5, 10,
15, 20, 30, or 60 minutes, or a custom 5–180 minutes), choose apps to pause,
then enable Focus Mode. Review the disclosure and enable **SELAH Focus Mode**
in Android's Accessibility settings. Returning to SELAH shows whether setup
is complete.

Opening a selected app before completing the goal displays a reading gate.
**Read in SELAH** opens the last reading location and starts/resumes the
countdown. Progress is cumulative throughout the day. Selected apps unlock
when the goal is met, and a new goal starts at local midnight.

The unfinished countdown is visible across all SELAH pages, including pushed
settings pages. It shows a paused state outside the Bible reader and disappears
when the daily goal is complete or Focus Mode is disabled. The reading gate
offers Read in SELAH and Back to Home; Focus settings remain in SELAH Settings.

Only time with the Bible reader visible, SELAH focused, and the screen
unlocked counts. Settings, dialogs, app switching, background audio, and
screen-off time pause progress. This measures reader screen time, not proof
that someone understood or actively read every verse. The screen stays awake
during an unfinished reading session. Changing the goal retains today's
earned time. Removing all selected apps turns Focus Mode off.

Phone, default SMS, launcher, Android settings, SELAH, and core permission
screens are excluded from selection. Users can always disable Focus Mode or
its Android accessibility permission. This is a voluntary habit aid, not a
tamper-proof parental-control or device-administration lock. Some Android
vendors may stop the service; check the setup status if blocking stops.

## Privacy and storage

The native accessibility service subscribes only to window-state changes to
identify the foreground package. It cannot retrieve window contents and does
not read messages, passwords, or screen text. The current package is transient;
SELAH does not build an app-usage history or send this information to a server.
No broad `QUERY_ALL_PACKAGES` permission is used: the picker queries launchable
apps only.

Configuration and daily time are stored in Android private SharedPreferences
(`selah_focus_v1`), separately from Scripture annotations and their export files.
Progress is saved approximately every five seconds and on foreground/reading
transitions; an abrupt process kill may lose the last few seconds. Permissions
and app choices are specific to this Android installation. Web/iOS builds do
not expose this Android feature. GitHub Pages does not provide app blocking.

## Implementation and checks

`FocusClock` uses monotonic elapsed time, discards suspension gaps, and resets
on local date changes. `FocusStore` requires reader visibility, native activity
resume/focus, and an unlocked interactive device. Flutter never supplies earned
seconds. Routes above the reader pause it through `FocusRouteObserver`.
`FocusAccessibilityService` presents a separate native gate when necessary;
its Back action returns Home.

Run `flutter test`, `flutter analyze`, and, from `android`,
`gradlew.bat :app:testDebugUnitTest`. Native clock tests cover paused/background
intervals, sleep gaps, restored progress, goal completion, and midnight reset.
Flutter tests cover goal changes preserving selections, declining disclosure,
and selecting apps. Device checks should also cover permissions, opening a
selected app, entering the reader from the gate, background/locked pauses,
and unlocking after completion. Do not silently enable accessibility on a
user's phone.

Verified on an Android 12 emulator: selecting Calculator, explicit disclosure,
service connection, opening the reading gate, entering the Bible reader,
pausing with a dialog/background/locked screen, and unlocking Calculator after
completion. The completion check restored a controlled emulator fixture with
one second remaining; the actual reader earned the final second. No test-only
progress controls are exposed in the app. The debug APK was also installed as
an update on the connected Android 12 V2022 phone; its accessibility permission
was left for the user to approve.
