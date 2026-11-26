# asb_house_hub

A comprehensive Flutter application for ASB House Hub, featuring house point tracking, digital campus ID passes, conduct evaluations (merits and demerits), and live interactive leaderboards.

## Audit and backend readiness

The [26 November 2026 deep audit](ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md) records verified fixes, 44 remaining findings, test evidence, and reproduction commands. See [Blaze requirements](election_audit/BLAZE_REQUIRED_FEATURES.md) before deploying backend services. Local fixes have not been deployed; passing builds do not establish production readiness.

## Features

- **Live House Standings**: Real-time points breakdown for all school houses (Ruby, Sapphire, Emerald, Diamond).
- **Interactive Leaderboards**: View top student contributors for each house with podium rankings.
- **Digital Campus ID Pass**: Student barcode and QR code passes with verifiable scholar details.
- **Conduct Evaluation & Scanner**: Faculty and council tool to scan student IDs, log merits (+5 to +50 pts) or infractions (-5 to -50 pts), and automatically update house totals with atomic Firestore transactions.
- **Student Contribution Records**: Detailed personal history of earned house points, merits, and demerits.

## Getting Started

1. Ensure Flutter 3.x+ is installed.
2. Run `flutter pub get` to install dependencies.
3. Launch with `flutter run -d windows` (or target device).
