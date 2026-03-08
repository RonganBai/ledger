# Architecture Overview

## 1. Overall Structure

The project is a Flutter multi-platform app (Android/iOS/Web/Desktop). Core business logic is under `lib/`.

- `app/`: app shell, theme, and global configuration
- `data/db/`: Drift database, table definitions, and data access
- `features/`: feature modules organized by business domain
- `services/`: cross-module services (cloud sync, background tasks, logging)
- `ui/pet/`: pet overlay UI and controls

## 2. Module Boundaries

### Auth (`features/auth`)

- Handles login, session state, and password reset flows.
- Uses Supabase Auth for user identity and session management.

### Ledger (`features/ledger`)

- Handles ledger home, transaction list, and CRUD operations.
- Depends on local database tables such as `transactions`, `accounts`, and `categories`.

### Reports (`features/reports`)

- Provides analytics, trends, category ratio, and history summaries.
- Builds aggregated results from local database queries.

### Import (`features/import`)

- Parses external bill files (for example CSV/XLSX).
- Performs deduplication and writes normalized records into local transaction tables.

### Settings (`features/settings`)

- Handles user preferences such as theme, language, reminders, and import/export settings.

## 3. Data Layer Design

### Local Storage

- Uses Drift to manage local SQLite data.
- Key tables include `accounts`, `transactions`, `categories`, `recurring_transactions`, and `sync_state`.

### Cloud Sync

- Uses Supabase/Postgres tables such as `ledger_accounts` and `ledger_bills`.
- Uses RLS (Row Level Security) to ensure users can only access their own data.
- Main sync logic is in `services/cloud_bill_sync_service.dart`.

## 4. Key Data Flow

1. User creates or edits data from the UI.
2. Changes are persisted in local Drift storage first.
3. If authenticated, cloud sync service uploads/downloads and merges data.
4. Reports read aggregated data from local storage instead of directly depending on cloud responses.

## 5. Current Engineering Notes

- Repository currently includes archive files (such as `lib.zip`, `assets.zip`); verify whether they should remain in main branches.
- `lib/main.dart` contains direct Supabase initialization values; for public repositories, prefer environment-based injection.
- `lib/data/db/` includes overlapping table directory structures; a later cleanup pass is recommended.
