# Verification performed on 6 September 2026

## Passed

- Swift 6.1.2 frontend parsed all app, monitor and core Swift source files.
- 13 core test methods executed with actual Swift source and synthetic pose fixtures;
  all assertions passed. The synchronous adapter `scripts/run_core_checks.py` was used.
  It changes only the XCTest runner/assertion surface, not production code or test bodies.
- OpenStep parser accepted the Xcode project; referenced source files exist; app and
  embedded monitor targets, entitlements, Info.plists and shared scheme are structurally valid.

The tests cover complete push-up and squat cycles; no duplicate count while holding;
standing rejection; plank stop/resume and continuous PR; camera gaps/background;
occlusion and multiple people; single-frame jitter; mirrored geometry; 10-second
reward boundaries; idempotent saves; persisted and exercise-specific PRs; insufficient
balance; one-time failed-reservation refunds; stale callback and stale save handling.

## Runner limitation

`swift test` could not complete in this container because SwiftPM/libdispatch encountered
an environment-related runtime crash. A direct XCTest invocation reported 13 passes but
also emitted runtime diagnostics. The final synchronous Swift adapter completed with
exit code 0 and all 13 assertions groups passing, without runtime diagnostics.

## Not verified

- Full iOS SDK type checking, Xcode simulator build, signing or archive validation.
- Real camera pose accuracy, lighting, body-size variation, lifecycle UI or visual layout.
- Real FamilyControls authorization, app shielding, OS usage callbacks or distribution approval.
- Whether the uploaded App Store build uses this repository's starter source or later local changes.

No real-iPhone tests have been performed and no recognition accuracy claim is made.
This deliverable is source prepared for integration and device validation, not a tested release.

## Integration of uploaded Mac project

The supplied Mac project has now been merged. Original Swift files matched the starter.
AppIcon PNG was preserved byte-for-byte (SHA-256
`0d214d3189bf2b3e2c5eb5bb47f50e92a41b252d42ad119e550803073f6569aa`).
Bundle ID, development team, Game Center, original compiler settings and iPhone/portrait
configuration were carried forward. App and monitor use version 1.1 / build 2.
Structural checks passed for both targets, source/resource paths, asset catalog,
entitlements and build versions.

The preceding implementation passed swift test and an unsigned app+monitor simulator
build on GitHub run 34049335799. The PR Checks tab records validation of this newer
integration commit; signing and real-device behavior still require testing on the Mac/iPhone.
