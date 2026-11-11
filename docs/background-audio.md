# Bible audio on Android

Start playback in Bible using WEB or BSB, then press Home or lock the phone.
SELAH continues streaming and automatically opens and plays the next chapter,
including across book boundaries. Playback ends after Revelation 22. Internet
is required. Starting audio does not minimize the app automatically.

Android's Bible audio media notification and lock-screen controls allow pause,
resume and seeking. Tapping the notification returns to SELAH. Manual chapter
or translation changes stop the previous recording. Leaving the Bible tab also
stops playback. Pausing retains the media service so playback can resume from
the notification; Stop releases it. Force-stopping the app ends playback.

The Android foreground media service uses just_audio_background/audio_service,
an audio wake lock, and speech audio focus. Natural chapter transitions retain
the player instead of tearing down the service in the background. No reading
time is credited to Focus Mode while the app is backgrounded or the screen is
locked. Background playback does not imply background reading credit.

Home uses a separate, explicitly owned scroll controller and PageStorage key,
so navigation or reader layout changes do not share its scroll state.

## Translation additions

Settings > Bible translations now includes Cebuano ULB (Balaan nga Bibliya) and
KJV as optional offline text downloads. OCCB remains bundled and the default.
Downloaded ZIPs and extracted Scripture hashes are verified before installing;
all 66 books and 1,189 chapters must validate. Cebuano ULB uses Cebuano book
names and retains Door43 contributor credits and CC BY-SA 4.0 notices. KJV
includes the UK rights notice. Web packages are served from the same origin.

These additions do not include recorded audio. Cebuano Bible Brain narration
requires an approved Bible Brain API key and verification of the specific
edition and allowed filesets. No other edition's recording is substituted for
the displayed translation.

iOS background-audio configuration is included for future iOS builds, but has
not been tested on an Apple device. Browser background playback depends on the
browser's media and power-management policies.

## Verification

The Android 12 Small_Phone emulator passed Home background playback, automatic
next-chapter playback with its screen locked, and media pause/resume/stop. Home
was also swiped down and back to the top on the emulator. The Flutter suite
passes 92 tests, including all six optional translation packages, home scroll
state across navigation/rebuilds, and continuation without stopping the player.

The native smoke test is part of JourneySmokeInstrumentation and can be run on
a test emulator with `-e audio true`. It waits for narrated Bible playback to
start, backgrounds and locks the emulator, seeks near the chapter end and
checks that the next chapter plays. Do not run instrumentation on a user's phone.
