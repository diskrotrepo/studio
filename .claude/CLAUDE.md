# Studio Project Rules

## Branch Safety

- **Before making ANY changes**, always check that the user is NOT on the `main` or `stable` branch. Run `git branch --show-current` first. If on `main` or `stable`, STOP and tell the user to create/switch to a feature branch before proceeding.

## UI / Flutter

- Never use mobile-style animations or transitions in the Flutter app. This is a desktop application. Avoid `AnimatedContainer`, `AnimatedCrossFade`, `AnimatedRotation`, `AnimatedSwitcher`, `AnimatedOpacity`, `SlideTransition`, `FadeTransition`, swipe gestures, and similar animated widgets. Use instant state changes (e.g. `if`/`switch` conditionals, `Container`, `Transform.rotate`) instead.
- `TabBarView` controllers must use `animationDuration: Duration.zero` and `NeverScrollableScrollPhysics`.
- Page transitions are already disabled via `NoTransitionsBuilder` in `app_theme.dart` — do not re-enable them.

## Backend / Database

- **Always use `customStatement()` / `customStatements()` for ALL database schema changes** (creating tables, adding columns, creating indices, etc.) in both `onCreate` and `onUpgrade` migrations. Never use Drift's `m.createTable()`, `m.addColumn()`, or `m.createAll()` — the generated versioned schema incorrectly maps boolean columns as `DriftSqlType.int` with SQLite-specific `$customConstraints`, which produces invalid SQL on PostgreSQL (e.g. `bigint ... DEFAULT FALSE` type mismatch). Write raw PostgreSQL DDL strings instead.
