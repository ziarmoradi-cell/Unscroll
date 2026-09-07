# Unscroll 1.2 – validation

## Automated gates

The GitHub workflow builds the native app and embedded monitor with Xcode 26.3 and
runs the core Swift package. It also installs and launches the unsigned simulator app
and captures onboarding plus all five main tabs using isolated, empty test data.

Core tests cover complete push-up/squat cycles, missing frames, pose loss, multiple people,
mirroring, jitter, valid plank duration and continuous PR, reward boundaries, stale callbacks,
idempotent checkpoints, old-ledger migration, step caps/deduplication, daily limits/refunds,
strict pause expiry and interrupted focus. The final run link is recorded in the delivered update.

## Required physical-iPhone acceptance (not executed in the remote workspace)

1. Install over the existing app with the same bundle ID. Check existing balance/PRs/history,
   new onboarding, profile edits and relaunch persistence. Do not delete the installed app first.
2. Grant camera access. Perform ten full push-ups and ten squats side-on in both directions.
   Compare physical and counted reps. Repeat in different lighting; partial movements must not count.
3. Plank: 9/10/19/20 valid seconds yield 0/1/1/2 minutes. 12 seconds, break, 8 seconds yields
   about 20 total, PR about 12. Covered lens, posture loss and backgrounding pause counting.
4. Beat a PR and relaunch; record, history and credit persist. Camera denial/retry must work.
5. Connect motion permission and walk. Today's steps load; reopening never doubles rewards.
   1,000 steps = 1 minute; cap 10 minutes/day. Verify day rollover and denied permission.
6. Select social apps with FamilyControls. Redeem one minute; combined selected-app usage should
   re-shield them, including while Unscroll is closed. Test failed setup, revocation and device reboot.
7. Strict focus, night pause and hardcore detox prevent redemption and selection edits. Starting
   these closes existing grants with disclosed forfeiture. Confirm early exit records interruption.
   Normal detox respects the smaller of 30 minutes/day and personal allowance.
8. Focus 15/25/50-minute end times survive backgrounding/relaunch. Finish early vs finish on time;
   completed totals must differ. Check thought note persistence.
9. Play each noise, adjust volume, lock the phone, wait for timer expiry. Audio must stop;
   calls/audio interruptions must stop sound cleanly. Switching sections must not start a second player.
10. iOS 26+: allow AlarmKit. Schedule a near alarm; test with app terminated, locked phone, silent
    mode and Focus. Test a full 30-minute pair: stopping the early chime leaves the final alarm;
    cancelling in Unscroll removes both. Denied authorization and changed alarm date must surface honestly.
    Earlier iOS: verify explicit reminder-only copy; use Apple's Clock for reliable waking.
11. Enable Game Center in App Store Connect, authenticate two real accounts, send an invitation
    through Apple's sheet, accept, and refresh the friend list. ShareLink only sends after user action.
12. Check large text, VoiceOver labels, small iPhone layouts, navigation and keyboard dismissal.

## Release boundary

CI is an unsigned compiler/logic/render check, not proof of device recognition accuracy or signed
capabilities. App Store upload, Apple review, Family Controls distribution permission, actual camera
calibration, alarms and Game Center account checks remain device/account operations. No production
screen-time baseline, sleep-stage inference, live friend exercise feed or unbypassable lockdown is claimed.
