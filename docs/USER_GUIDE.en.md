# Ledger App User Guide

This guide covers the current major features shipped in the app, including daily bookkeeping, cloud sync, feedback, and the admin console.

## 1. Getting Started

### Sign in or sign up

1. Open the app.
2. Choose `Login` if you already have an account.
3. Choose `Sign Up` if you need a new account.
4. Enter your email and password.
5. If email verification is enabled, finish verification before logging in.

### Continue as guest

You can also choose `Continue as Guest`.

Guest mode is useful for quick local use, but it has limits:

- No Supabase cloud sync
- No account email or password management
- Some account-related features are unavailable

## 2. Language and Theme

The app supports both Chinese and English.

- On the login page, use the language switch in the top-right corner.
- After logging in, you can switch language and theme from Settings.
- You can also change theme style, background image, and background mist level.

## 3. Ledger Basics

### Accounts

Accounts are the containers for your bills.

Typical examples:

- Cash
- Bank card
- Alipay
- WeChat Pay

Supported account actions:

- Create account
- Rename account
- Sort account order
- Activate or deactivate account
- Switch the current account

Each signed-in user now has fully isolated local accounts. One user's local accounts will not appear under another user.

### Bills

You can add and manage bills in the ledger home page.

Supported bill directions:

- `income`
- `expense`
- `pending`

Common bill fields:

- Amount
- Date and time
- Merchant
- Memo
- Category

## 4. Reports and Analytics

The Reports module helps you review your financial activity.

Available analysis includes:

- Trend charts
- Category ratio
- History summary
- Time-based aggregation

Use this page to understand spending patterns and income changes over time.

## 5. External Bill Import

The app supports importing bills from external platforms.

Supported sources currently include:

- WeChat Pay
- Alipay
- PNC

General flow:

1. Export a bill file from the source platform.
2. Open the import page in the app.
3. Choose the matching source type.
4. Select the exported file.
5. Review and import the records.

## 6. Recurring Transactions

You can create recurring transactions for repeated income or expenses.

Typical use cases:

- Salary
- Rent
- Subscription payments
- Fixed monthly transfers

The recurring transaction module helps reduce repeated manual input.

## 7. Cloud Sync

Signed-in users can use Supabase cloud sync.

Main behaviors:

- Download cloud bills after login
- Upload local changes to the cloud
- Keep local and cloud data aligned

If an account does not exist for the current signed-in user, the app creates a proper local account context instead of reusing another user's local account.

## 8. Account Profile

The profile page stores your account-related identity settings.

Current behavior:

- The display name defaults to the registered email
- You can update the display name later
- The public display name is used in admin management and feedback tracking

## 9. User Feedback

The Settings page includes a feedback entry.

### How to send feedback

1. Open Settings.
2. Tap the feedback icon in the top-right corner.
3. Enter your feedback in the large text box.
4. Tap `Send Feedback`.

### Feedback rules

- Each user has up to 5 feedback submissions per day
- The quota refreshes at `UTC+8`
- Feedback is sent through the server-side mail function
- The admin side can review, filter, and mark feedback as resolved

If you do not set a custom display name, the system uses your registered email in a masked form for identity distinction.

## 10. Blocked Accounts

Admins can disable accounts.

If your account has been blocked:

- You cannot continue to use protected features
- You will be signed out when access is checked
- The login page will show an `Account Blocked` dialog

## 11. Admin Login Flow

Admin users share the same login system as normal users.

Admin flow:

1. Log in with the normal account system.
2. The app checks whether the user exists in the admin table.
3. If the user is an admin, a 4-digit admin PIN confirmation page is shown.
4. After the PIN is verified, the admin entry page appears.

The admin entry page includes:

- App entry
- Admin console entry

## 12. Admin Console

The admin console is split into multiple sections.

### Dashboard

The dashboard shows overview metrics such as:

- Pending feedback count
- Suspicious high-frequency feedback users
- Request trend chart
- Total users
- Total admins
- Disabled users

### User Permissions

Admins can:

- Search by email, nickname, or masked email
- Filter by role and feedback status
- Promote a normal user to admin
- Demote another admin to normal user

Safety rules:

- The current admin cannot demote itself
- The last active admin cannot be removed

### User Blocking

Admins can:

- Disable a user
- Restore a disabled user
- Review disabled reasons

Safety rules:

- The current admin cannot disable itself
- The last active admin cannot be disabled

### Feedback Management

Admins can:

- View recent feedback
- Filter by status
- Search by user or content
- Mark feedback as resolved
- Open the related user detail page

### User Detail Page

The user detail page shows:

- Registered email
- Display name
- User ID
- Created time
- Role status
- Disabled status
- Feedback statistics
- Recent feedback
- Audit logs

## 13. Audit Logs

Important admin actions are recorded.

Current audit log actions include:

- Grant admin
- Revoke admin
- Disable user
- Restore user
- Resolve feedback

## 14. Release Version

This guide matches the major admin and feedback update line introduced in version `2.x`.
