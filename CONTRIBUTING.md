# Contributing to Studio

Thanks for your interest in contributing to Studio! This guide will help you get started.

## Getting Started

### Prerequisites

- **Windows**: Windows 10/11 with WSL2
- **macOS**: macOS 12+
- Git, Docker, Dart SDK (>=3.8), Flutter SDK (stable channel)

### Dev Environment Setup

Run the setup script to install prerequisites, configure the environment, fetch dependencies, run code generation, and start supporting services:

**Windows:**
```
setup-dev.bat
```

**macOS / Linux:**
```bash
./setup-dev.sh
```

Pass `--skip-docker` to skip Docker installation and service startup.

### Building from Source

| Script | What it rebuilds |
|---|---|
| `dev.bat` / `dev.sh` | Backend + UI only (fast iteration) |
| `dev-all.bat` / `dev-all.sh` | All services including models |

### Running Tests

**Backend:**
```bash
cd packages/studio_backend
dart test
```

**UI:**
```bash
cd packages/studio_ui
flutter test
```

## Project Structure

```
studio/
├── packages/
│   ├── studio_backend/   # Dart/Shelf REST API server
│   └── studio_ui/        # Flutter web app (desktop-first)
├── models/
│   ├── ACE-Step-1.5/     # Music generation model
│   ├── bark/             # Speech/audio generation
│   ├── llama.cpp/        # YuLan-Mini text model via llama.cpp
│   └── midi/             # MIDI generation
├── installer/            # One-command installers (Windows/macOS)
└── docker-compose.yml    # Service orchestration
```

## Code Style

### Flutter / Dart

- This is a **desktop web application**. Never use mobile-style animations or transitions (`AnimatedContainer`, `AnimatedSwitcher`, `SlideTransition`, swipe gestures, etc.). Use instant state changes instead.
- `TabBarView` controllers must use `animationDuration: Duration.zero` and `NeverScrollableScrollPhysics`.
- Run `dart analyze --fatal-infos` (backend) and `flutter analyze --fatal-infos` (UI) before submitting.

### Database Migrations

Always use `customStatement()` / `customStatements()` for all schema changes in both `onCreate` and `onUpgrade`. Never use Drift's generated migration helpers (`m.createTable()`, `m.addColumn()`, `m.createAll()`) — they produce invalid SQL on PostgreSQL.

## Submitting Changes

1. Fork the repository and create a branch from `main`.
2. Make your changes, following the code style above.
3. Add or update tests as appropriate.
4. Ensure `dart analyze --fatal-infos` and `flutter analyze --fatal-infos` pass.
5. Ensure all tests pass.
6. Open a pull request against `main`.

## Reporting Bugs

Open an issue using the **Bug Report** template. Include:
- Steps to reproduce
- Expected vs actual behavior
- OS, GPU, and Docker version
- Relevant logs (check Dozzle at `localhost:9999`)

## Requesting Features

Open an issue using the **Feature Request** template describing the use case and proposed solution.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
