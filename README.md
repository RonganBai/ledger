# Ledger App

[English](README.md) | [中文](README.zh-CN.md)

A multi-platform ledger app built with Flutter, supporting offline local bookkeeping, cloud sync, reporting, recurring transactions, and external bill import.

## Features

- Multi-account ledger management (`income`, `expense`, `pending`)
- Offline-first local storage with Drift
- Supabase authentication and cloud bill synchronization
- Reports and deep analysis (trends, category ratio, history summary)
- External bill import (WeChat Pay / Alipay / PNC)
- Recurring transaction management
- Chinese/English language switching, theme switching, custom background image, and pet overlay UI

## Tech Stack

- `Flutter` / `Dart`
- `drift` + `sqlite` (local data)
- `supabase_flutter` (auth + cloud sync)
- `fl_chart` (charts)
- `shared_preferences` (persistent settings)
- `image_picker` / `file_picker` (image & file import)

## Project Structure

```text
lib/
  app/                 # App-level config (theme, settings, app shell)
  data/db/             # Drift database and table definitions
  features/
    auth/              # Login / password reset
    ledger/            # Ledger home and transaction flows
    reports/           # Reporting and analytics
    import/            # External bill import
    settings/          # Settings and preferences
  services/            # Cloud sync, background services, logging
  ui/pet/              # Pet overlay UI and control logic
supabase/
  ledger_bills_schema.sql  # Supabase schema + RLS policies
docs/
  ARCHITECTURE.md      # Module and data-flow notes
```

## Quick Start

1. Install Flutter 3.35+ and ensure `dart --version` is `>= 3.11.x`.
2. Install dependencies:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Download APK

- Direct APK: https://github.com/RonganBai/ledger/releases/latest/download/ledger-app.apk
- Releases page: https://github.com/RonganBai/ledger/releases
- If the direct APK link is unavailable, open the Releases page and download the latest `.apk` asset.

## Release Status

- Current public release target: Android only.
- Google Play release is coming soon.
- iOS will not be publicly released for now because the Apple Developer Program cost is currently too high.

## Supabase Setup

1. Create a Supabase project.
2. Run [`supabase/ledger_bills_schema.sql`](supabase/ledger_bills_schema.sql) in the SQL editor.
3. Replace `Supabase.initialize(url, anonKey)` in `lib/main.dart` with your project config.

For public repositories, avoid hardcoding project keys. Prefer environment variables or build-time injection.

## Demo Assets Placeholder

You can add these files manually:

- `docs/media/demo.gif`
- `docs/media/home.png`
- `docs/media/report.png`

And embed in README:

```md
![Demo](docs/media/demo.gif)
```

## Development & Contribution

- Contribution process: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Architecture notes: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- PR template: `.github/PULL_REQUEST_TEMPLATE.md`

## Suggested Roadmap

- Improve cloud sync conflict strategy
- Increase unit/integration test coverage
- Make bill import rules configurable
- Standardize release and changelog workflow

## License

This project is licensed under [MIT License](LICENSE).
