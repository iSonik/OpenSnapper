# Contributing to OpenSnapper

Thanks for contributing.

## Development setup

1. Clone the repo.
2. Build and run:

```bash
swift run OpenSnapper
```

3. For app-bundle testing (permissions/signing):

```bash
./scripts/build-app.sh
./scripts/run-app.sh
```

4. Optional permission reset for local debugging:

```bash
./scripts/run-app.sh --reset-screen-capture
```

## Pull request guidelines

1. Keep PRs focused and small when possible.
2. Update docs for user-facing behavior changes.
3. Avoid machine-specific paths or personal identifiers.
4. Keep code style consistent with surrounding files.
5. Include a short validation note in the PR description.

## Bug reports

Include:

1. macOS version
2. OpenSnapper commit/version
3. Steps to reproduce
4. Expected result
5. Actual result
6. Crash log (`~/Library/Logs/DiagnosticReports`) if applicable
