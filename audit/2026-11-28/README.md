# Homework and Events remediation

Source baseline: `ccad2fb`, verified 28 November 2026.

- Homework notes and shared work links are saved with each student's submission
  and restored from its live snapshots. Direct file uploads are unavailable; the
  previous filename-only picker has been replaced with shared-link guidance.
- Acknowledged local changes yield to newer assignment data. Repeated taps are
  blocked while a write is pending; rejected writes retain the last saved state.
- Events covers take their height from their content. Tests cover 320, 360 and
  390dp screens at 100%, 130%, 150%, 200% and 300% text scaling.
- Valid-profile denial tests now reach the service failure path; rules emulator
  tests verify note persistence, ownership, length/type bounds and grading gates.

Validation: 747 Flutter tests, 29 Firestore/Storage emulator tests, clean Flutter
analysis and three backend syntax checks. Windows, Web, five APK variants and
the Android App Bundle were rebuilt. APK signatures verify and all three split
payloads match their architectures in the universal APK. All 22 Windows runtime
files in `dist/windows` match the release build.

Only the Firestore rules schema was deployed. Exact live/local parity was read
back after deployment; the seven composite indexes also match. No production
student records or billing settings were changed. No Cloud Functions or Storage
bucket is active. Physical-device testing, iOS archiving and other pre-existing
production-readiness gates remain open. The backend dependency audit still
reports ten moderate advisories and no high/critical advisories.

The catalogue Markdown is the content source for its HTML and PDF. The updated
verification JSON points to the logs and artifact manifest in this directory.
