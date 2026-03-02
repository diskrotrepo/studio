# s t u d i o///diskrot

Studio by diskrot is an offline generative music creation web app. It runs entirely on your machine — no cloud accounts, no subscriptions, no data leaves your computer.

## Features

- **Text-to-music generation** — Describe a song with lyrics, genre, BPM, and key; get a full audio track back (ACE-Step 1.5)
- **Speech and audio generation** — Generate speech and sound effects (Bark)
- **Text generation** — Local LLM for lyrics writing and audio prompts (YuLan-Mini via llama.cpp)
- **MIDI generation** — Generate and arrange MIDI compositions (optional)
- **LoRA training** — Fine-tune music models on your own audio data
- **Song management** — Organize, tag, and iterate on generated songs
- **Fully offline** — Everything runs locally via Docker; no internet required after initial setup

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Browser  →  Studio UI (Flutter web, :3000)         │
│               ↓                                     │
│            Studio Backend (Dart/Shelf, :8080)        │
│               ↓              ↓            ↓         │
│          ACE-Step(:8001)  Bark(:8002)  YuLan(:8003) │
│               ↓                                     │
│          PostgreSQL(:5432)  Redis(:6379)             │
└─────────────────────────────────────────────────────┘
```

| Layer | Technology |
|---|---|
| Frontend | Flutter web (desktop-first) |
| Backend | Dart, Shelf, Drift (PostgreSQL) |
| Music generation | ACE-Step 1.5 (PyTorch) |
| Speech/audio | Bark (PyTorch) |
| Text/LLM | YuLan-Mini via llama.cpp (CPU or CUDA) |
| MIDI | Custom transformer model (PyTorch, optional) |
| Infrastructure | Docker Compose, PostgreSQL 16, Redis 7 |

## System Requirements

- **OS**: Windows 10/11 (with WSL2) or macOS 12+
- **RAM**: 16 GB minimum, 32 GB recommended
- **Disk**: ~20 GB for Docker images and model weights
- **GPU** (optional): NVIDIA GPU with 8+ GB VRAM for accelerated generation. CPU-only mode works on all hardware.

## Install

**Windows** — open PowerShell as Administrator and paste:
```powershell
irm https://raw.githubusercontent.com/diskrot/studio/main/installer/install.ps1 -OutFile $env:TEMP\diskrot-install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\diskrot-install.ps1
```

**macOS** — open Terminal and paste:
```bash
curl -fsSL https://raw.githubusercontent.com/diskrot/studio/main/installer/install.sh -o /tmp/diskrot-install.sh && bash /tmp/diskrot-install.sh
```

The installer handles everything — WSL, Docker, NVIDIA drivers, GPU detection, and launching the stack. First startup downloads model weights and may take several minutes.

## Update

Run the same installer again, or use the launcher scripts (`start.bat` / `start.sh`) in the project folder. Both auto-detect whether to install or update.

## Uninstall

| Platform | Command |
|---|---|
| **Windows** | Double-click `installer/uninstall.bat` |
| **macOS** | `./installer/install.sh --uninstall` |

## Usage

Once running, open **http://localhost:3000** in your browser.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full development guide.

### Quick start

Run the setup script to install all development prerequisites (Git, Docker, Dart SDK, Flutter SDK), configure the environment, fetch dependencies, run code generation, and start supporting services:

**Windows:**
```
setup-dev.bat
```

**macOS / Linux:**
```bash
./setup-dev.sh
```

Pass `--skip-docker` to skip Docker installation and service startup.

### Nightly (dev-channel) images

To test the latest changes from the `main` branch before they land in a stable release, use the nightly scripts. These pull pre-built `-dev` tagged images from Docker Hub — no local build required.

| Script | Platform |
|---|---|
| `start-nightly.bat` | Windows |
| `start-nightly.sh` | macOS / Linux |

| Flag | Description |
|---|---|
| `--gpu` | Force GPU compose overlay |
| `--cpu` | Force CPU-only (skip GPU overlay) |
| `--pull-only` | Pull images without starting services |

Or manually:
```bash
docker compose -f docker-compose.yml -f docker-compose.nightly.yml up -d
```

### Building from source

To build from local source instead of pulling prebuilt images:

| Script | What it rebuilds |
|---|---|
| `dev.bat` / `dev.sh` | Backend + UI only (fast iteration) |
| `dev-all.bat` / `dev-all.sh` | All services including models |

<details>
<summary>Dev script flags</summary>

| Flag | Description |
|---|---|
| `--no-cache` | Rebuild without Docker layer cache |
| `--build-only` | Build images and exit (don't start services) |
| `--gpu` | Force GPU compose overlay |
| `--cpu` | Force CPU-only (skip GPU overlay) |

</details>

<details>
<summary>Services</summary>

| Service | Port | Notes |
|---|---|---|
| **studio-ui** | `3000` | Flutter web app |
| **studio-backend** | `8080` | Dart API server |
| **acestep** | `8001` | Music generation (CPU or GPU) |
| **yulan** | `8003` | Text model via llama.cpp (CPU or GPU) |
| **postgres** | `5432` | Database |
| **redis** | `6379` | Cache/queue |
| **pgadmin** | `5050` | DB admin UI |
| **bark** | `8002` | Speech/audio generation (CPU or GPU) |
| **midi** | `8004` | MIDI generation (optional profile) |
| **dozzle** | `9999` | Docker log viewer |
| **redisinsight** | `5540` | Redis admin UI |

</details>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on setting up the dev environment, code style, and submitting changes.

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## License

This project is licensed under the [MIT License](LICENSE).

Vendored dependencies carry their own licenses:
- [ACE-Step 1.5](models/ACE-Step-1.5/LICENSE) — MIT (some model files Apache 2.0)
- [Bark](models/bark/LICENSE) — MIT
- [llama.cpp](models/llama.cpp/vendor/LICENSE) — MIT
- [nano-vllm](models/ACE-Step-1.5/acestep/third_parts/nano-vllm/LICENSE) — MIT
