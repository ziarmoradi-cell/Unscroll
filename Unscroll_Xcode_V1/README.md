# Unscroll 1.2.1

Native SwiftUI app for movement-earned social-media time, focus and digital breaks.
This update preserves the supplied Mac project's bundle ID `com.ziar.unscroll`, team,
AppIcon and signing settings. Version 1.2.1 / build 4; iOS 17.4+, Xcode 26+ recommended.

## Product

- Warm offwhite, deep ink and petrol design, dark evening card, five main tabs.
- Persistent four-step onboarding: name, optional age, goal and difficulty. Repeat in Profile.
- On-device Vision joint detection; complete push-up/squat cycles and valid plank timing.
- Separate per-exercise records; live new-record banner and haptic; persisted workout history.
- 10 valid plank seconds = 60 credited seconds. Valid segments accumulate within a workout;
  the longest uninterrupted segment sets its PR. Incomplete reward blocks don't carry across workouts.
- Push-up/squat rates preserve existing settings (default 30 seconds per rep).
- CMPedometer reads today's iPhone steps with explicit permission. 1,000 steps = 60 seconds,
  capped at 10 minutes per local calendar day. Repeated/older samples cannot credit twice.
  Steps catch up on foreground entry; Apple Watch and HealthKit totals are not imported.
- Daily movement goals, completed-focus minutes, active days and earned milestones use real local records.
- FamilyControls picker, ManagedSettings shields, embedded DeviceActivityMonitor. Budget is
  reserved before unlocking and ends after aggregate selected-app usage reaches the threshold,
  or after 24 hours. Early termination forfeits the remaining reserved amount.
- Daily redemption ceiling. Strict focus, night pause and hardcore detox disable redemption.
  Selection cannot change during a grant or restrictive pause.
- 15/25/50-minute focus, intention, interruption tracking, persistent end time and thought parking.
  Timer completion survives leaving the app; it is elapsed focus commitment, not attention measurement.
- Locally synthesized white/brown/ocean noise with volume and expiry. No streams or downloaded audio.
- Night pause, daily evening checklist and 15/30/60-minute sound timer.
- AlarmKit on iOS 26+ (built with Xcode 26+): gentle custom chime at the beginning of a
  30-minute window plus a system alarm at the deadline. Each stops independently; the final
  alarm still rings if the early one is stopped. A near-term deadline schedules only the final alarm.
  The pair is one-shot and can be cancelled in the app. No sleep-stage inference.
  Older SDK/OS combinations offer labeled local-notification reminders, never a claimed reliable alarm.
- 7/14/30-day detox: normal caps redemption at 30 minutes/day, hardcore pauses all redemption.
  Personal limits can be stricter. Explicit early exit is logged; permission revocation in iOS remains possible.
- Game Center authentication, friend list and current system friend-request creator. No invented
  friend activity, private backend or automatic progress sharing; ShareLink is user initiated.
- Practical tips for Focus / DND, True Tone, Night Shift and grayscale with Apple links.
  iOS system toggles remain under the user's control.

## Data and integrity

App and monitor share a locked, atomic JSON ledger in `group.com.ziar.unscroll`.
The optional wellbeing field migrates older ledgers without resetting balance, PRs or history.
Legacy `earnedMinutes` migrates once. Workout snapshots and step rewards are idempotent.
Failed reservations refund credit and the daily allowance; stale monitor callbacks cannot end newer grants.
Corrupt/unavailable storage surfaces an error instead of silently clearing progress.
Profile, age, notes, motion and workout data remain local. Camera frames are not saved or uploaded.
Privacy manifests declare UserDefaults and uptime duration measurement.

## Build and validation

```sh
cd Unscroll_Xcode_V1
swift test
xcodebuild -project Unscroll.xcodeproj -scheme Unscroll -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

CI chooses the newest stable installed Xcode, runs core tests, builds app and extension and
captures actual simulator screenshots. UI fixtures compile only for DEBUG simulator builds and
use a separate temporary ledger, with zero balance/history. No test reset exists in device/release builds.
See `VALIDATION.md` for evidence and the required physical-device checks.

Project generation: `python3 scripts/generate_project.py` from repository root. Modify the generator
when changing project resources or settings. `MacProjectSettings.json` retains imported build settings.
See `START-HIER.md` for German update/install instructions.

## Physical-device and Apple boundaries

Synthetic geometry tests prove state-machine rules, not camera recognition accuracy across bodies,
lighting and camera placements. No replay/liveness prevention is claimed. DeviceActivity callbacks
and permission availability depend on iOS. App Groups and Family Controls profiles must match;
Family Controls distribution needs Apple's entitlement approval for app and extension.
Game Center requires the App Store Connect configuration. No App Store upload is performed by CI.

## Apple API references

- https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest
- https://developer.apple.com/documentation/coremotion/cmpedometer
- https://developer.apple.com/documentation/deviceactivity/deviceactivityevent/includespastactivity
- https://developer.apple.com/documentation/xcode/configuring-family-controls
- https://developer.apple.com/documentation/alarmkit
- https://developer.apple.com/documentation/gamekit/gklocalplayer/presentfriendrequestcreator(from:)-7j1kn
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

## Camera feedback correction (1.2.1)

The old all-joint confidence cutoff and 150 ms endpoint holds prevented valid fast movements
from counting and made acquisition unnecessarily strict. The counter now requires only
exercise-relevant joints (no hands for squats), accepts moderate-confidence detections,
uses two endpoint observations with full depth/return hysteresis and a 180 ms minimum
cycle as an anti-spike check. It no longer enforces an 800 ms exercise pace. Processing targets
up to 30 fps subject to device performance. Full depth, return and actual detected frames
remain necessary: missed camera observations cannot be reconstructed.

A live joint/line overlay shares the preview's aspect-fit projection and mirror setting.
Orange displays detected body parts even before the posture qualifies; green marks accepted
posture. Missing joints and camera-placement guidance are explicit. Camera opens with the
workout, front/rear switching resets the movement phase, and stale overlays clear on interruption.
The reward label now explicitly says social-media credit, not repetition duration.

Synthetic regression tests cover fast cycles, shallow reps, partially occluded squat hands,
moderate-confidence plank, hidden support hands and overlay letterboxing/mirroring.
These checks do not prove real camera accuracy; physical-device re-testing remains required.
