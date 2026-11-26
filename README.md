# asb_house_hub

A comprehensive Flutter application for ASB House Hub, featuring house point tracking, digital campus ID passes, conduct evaluations (merits and demerits), and live interactive leaderboards.

## Audit and backend readiness

The [26 November 2026 deep audit](docs/audits/ASB_HOUSE_HUB_DEEP_AUDIT_2026-11-26.md) and [feature catalogue](docs/reports/ASB_HOUSE_HUB_FEATURE_CATALOGUE.md) record verified fixes, findings, test evidence, and reproduction commands. See [Blaze requirements](docs/audits/elections/BLAZE_REQUIRED_FEATURES.md) before deploying backend services.

## Repository Structure

- `lib/` — Flutter application source (`models/`, `screens/`, `services/`, `theme/`, `widgets/`, `l10n/`)
- `test/` — Automated unit, widget, and rules-contract tests
- `functions/` — Firebase Cloud Functions (`elections-v2.js`, `library-v2.js`, `index.js`) and emulator security tests
- `docs/` — Organized documentation (`audits/`, `reports/`, `proposals/`, `assets/`)
- `tool/` — Development, icon, inventory, and gap-probe scripts (`scripts/` for Windows launch helpers)
- `audit/` — Local emulator gap-probe output directory (`known-gap-probes.json`)

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
