# Contributing Guide

Thanks for contributing to Ledger App. Please follow this guide to keep code quality and collaboration efficiency high.

## Development Environment

- Flutter `3.35+`
- Dart `3.11+`
- `flutter_lints` enabled

## Branch Strategy

- `main`: stable branch
- Feature work: `feat/<short-name>`
- Bug fixes: `fix/<short-name>`
- Documentation updates: `docs/<short-name>`

## Workflow

1. Pull the latest code from `main` and create a new branch.
2. Run checks before opening a PR:

```bash
flutter analyze
flutter test
```

3. Use clear commit messages:

```text
feat: add xxx
fix: resolve xxx
docs: update xxx
refactor: optimize xxx
```

4. Open a PR and complete the PR template, including change summary, test results, and risk notes.

## Code Guidelines

- Keep modules focused and avoid oversized widgets/services.
- Place business logic in `services/` or feature-scoped modules under `features/*/`.
- If database schema changes are introduced, update related docs and migration steps together.
- Never commit sensitive local files (keys, signing files, private certificates).

## Issue Reporting

When reporting bugs or feature requests, use templates under `.github/ISSUE_TEMPLATE/` and include:

- Reproduction steps
- Expected behavior vs. actual behavior
- Device/system/Flutter versions
- Screenshots or logs (if available)
