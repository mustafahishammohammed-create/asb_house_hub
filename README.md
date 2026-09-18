# asb_house_hub

A comprehensive Flutter application for ASB House Hub, featuring house point tracking, digital campus ID passes, conduct evaluations (merits and demerits), and live interactive leaderboards.

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
