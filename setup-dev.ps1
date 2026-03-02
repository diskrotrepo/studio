<#
.SYNOPSIS
    studio///diskrot -- Developer Environment Setup (Windows)
.DESCRIPTION
    Installs development prerequisites, configures the environment, fetches
    dependencies, runs code generation, and starts supporting Docker services.

    After running this script you can:
      cd packages\studio_backend; dart run bin\server.dart   (backend)
      cd packages\studio_ui; flutter run -d chrome           (UI)

    Usage:
      .\setup-dev.ps1                Full setup
      .\setup-dev.ps1 -SkipDocker   Skip Docker install & service startup
.PARAMETER SkipDocker
    Skip Docker Desktop installation and service startup.
#>
[CmdletBinding()]
param(
    [switch]$SkipDocker
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $PSCommandPath
Push-Location $ScriptDir

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Banner {
    param([string]$Text)
    $line = "=" * 60
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "[*] $Text" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[!] $Text" -ForegroundColor DarkYellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host "[X] $Text" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Test-DockerRunning {
    try {
        $null = docker info 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Wait-ForDocker {
    param([int]$TimeoutSeconds = 120)
    Write-Step "Waiting for Docker Desktop to be ready..."
    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        if (Test-DockerRunning) {
            Write-Ok "Docker is running."
            return $true
        }
        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "  Waiting... ($elapsed s)" -ForegroundColor DarkGray
    }
    return $false
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Get-NvidiaGpu {
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name -match "NVIDIA" } |
            Select-Object -First 1
        return $gpu
    } catch {
        return $null
    }
}

# ==============================================================================
Write-Banner "studio///diskrot -- Dev Environment Setup"
# ==============================================================================

# ── Step 1: Git ──────────────────────────────────────────────────────────────

Write-Banner "Step 1: Git"

if (Test-CommandExists git) {
    $gitVer = git --version
    Write-Ok "Git is installed ($gitVer)."
} else {
    if (Test-CommandExists winget) {
        Write-Step "Installing Git via winget..."
        winget install --id Git.Git --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-CommandExists git) {
            Write-Ok "Git installed."
        } else {
            Write-Fail "Git installation failed. Install manually: https://git-scm.com"
            Pop-Location; exit 1
        }
    } else {
        Write-Fail "Git not found and winget not available."
        Write-Host "  Install Git from https://git-scm.com" -ForegroundColor White
        Pop-Location; exit 1
    }
}

# ── Step 2: Docker Desktop ──────────────────────────────────────────────────

if (-not $SkipDocker) {
    Write-Banner "Step 2: Docker Desktop"

    if (Test-CommandExists docker) {
        Write-Ok "Docker CLI found."
        if (Test-DockerRunning) {
            Write-Ok "Docker Desktop is running."
        } else {
            Write-Step "Starting Docker Desktop..."
            $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerPath) {
                Start-Process $dockerPath
                if (-not (Wait-ForDocker -TimeoutSeconds 120)) {
                    Write-Warn "Docker Desktop is not responding. Start it manually later."
                }
            } else {
                Write-Warn "Docker Desktop executable not found. Start it manually."
            }
        }
    } else {
        if (Test-CommandExists winget) {
            Write-Step "Installing Docker Desktop via winget..."
            winget install --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
            Refresh-Path
            if (Test-CommandExists docker) {
                Write-Ok "Docker Desktop installed."
                Write-Step "Starting Docker Desktop..."
                $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
                if (Test-Path $dockerPath) {
                    Start-Process $dockerPath
                }
                if (-not (Wait-ForDocker -TimeoutSeconds 180)) {
                    Write-Warn "Docker Desktop is not responding yet. A reboot may be needed."
                }
            } else {
                Write-Warn "Docker Desktop installed but CLI not in PATH."
                Write-Host "  Restart your terminal or reboot, then re-run this script." -ForegroundColor White
            }
        } else {
            Write-Warn "Docker not found and winget not available."
            Write-Host "  Install Docker Desktop: https://www.docker.com/products/docker-desktop/" -ForegroundColor White
        }
    }
} else {
    Write-Step "Skipping Docker (-SkipDocker)."
}

# ── Step 3: Dart SDK ────────────────────────────────────────────────────────

Write-Banner "Step 3: Dart SDK"

if (Test-CommandExists dart) {
    $dartVer = dart --version 2>&1
    Write-Ok "Dart SDK found ($dartVer)."
} else {
    $installed = $false
    if (Test-CommandExists winget) {
        Write-Step "Installing Dart SDK via winget..."
        winget install --id Dart.Dart-SDK --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-CommandExists dart) {
            Write-Ok "Dart SDK installed."
            $installed = $true
        }
    }
    if (-not $installed -and (Test-CommandExists choco)) {
        Write-Step "Installing Dart SDK via Chocolatey..."
        choco install dart-sdk -y
        Refresh-Path
        if (Test-CommandExists dart) {
            Write-Ok "Dart SDK installed."
            $installed = $true
        }
    }
    if (-not $installed) {
        Write-Fail "Could not install Dart SDK automatically."
        Write-Host "  Install it from https://dart.dev/get-dart" -ForegroundColor White
        Pop-Location; exit 1
    }
}

# ── Step 4: Flutter SDK ─────────────────────────────────────────────────────

Write-Banner "Step 4: Flutter SDK"

if (Test-CommandExists flutter) {
    $flutterVer = (flutter --version 2>&1 | Select-Object -First 1)
    Write-Ok "Flutter SDK found ($flutterVer)."
} else {
    $installed = $false
    if (Test-CommandExists winget) {
        Write-Step "Installing Flutter SDK via winget..."
        winget install --id Google.Flutter --accept-package-agreements --accept-source-agreements
        Refresh-Path
        if (Test-CommandExists flutter) {
            Write-Ok "Flutter SDK installed."
            $installed = $true
        }
    }
    if (-not $installed -and (Test-CommandExists choco)) {
        Write-Step "Installing Flutter SDK via Chocolatey..."
        choco install flutter -y
        Refresh-Path
        if (Test-CommandExists flutter) {
            Write-Ok "Flutter SDK installed."
            $installed = $true
        }
    }
    if (-not $installed) {
        Write-Fail "Could not install Flutter SDK automatically."
        Write-Host "  Install it from https://docs.flutter.dev/get-started/install" -ForegroundColor White
        Pop-Location; exit 1
    }
}

# ── Step 5: Environment Configuration ───────────────────────────────────────

Write-Banner "Step 5: Environment Configuration"

$envFile = Join-Path $ScriptDir ".env"

if (Test-Path $envFile) {
    Write-Ok ".env file already exists."
} else {
    # Detect GPU to pick the right sample
    $gpu = Get-NvidiaGpu
    if ($gpu) {
        Write-Ok "NVIDIA GPU detected: $($gpu.Name)"
        $sampleFile = ".env.windows.sample"
    } else {
        Write-Step "No NVIDIA GPU detected. Using CPU mode."
        $sampleFile = ".env.mac.sample"
    }

    $samplePath = Join-Path $ScriptDir $sampleFile
    if (Test-Path $samplePath) {
        Copy-Item $samplePath $envFile
        Write-Ok ".env created from $sampleFile."
    } else {
        Write-Warn "Sample file $sampleFile not found. Create .env manually."
    }

    if (Test-Path $envFile) {
        Write-Host ""
        Write-Host "  Edit .env to set your HF_TOKEN (Hugging Face token) if you plan" -ForegroundColor White
        Write-Host "  to run the AI model services." -ForegroundColor White
        Write-Host "  Get a token at: https://huggingface.co/settings/tokens" -ForegroundColor Cyan
        Write-Host ""
    }
}

# ── Step 6: Data Directories ────────────────────────────────────────────────

Write-Banner "Step 6: Data Directories"

$dataDirs = @(
    "data\acestep-checkpoints",
    "data\acestep-output",
    "data\yulan-hf-cache",
    "data\yulan-gguf"
)
foreach ($dir in $dataDirs) {
    $fullPath = Join-Path $ScriptDir $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
    }
}
Write-Ok "Data directories ready."

# ── Step 7: Dart/Flutter Dependencies ───────────────────────────────────────

Write-Banner "Step 7: Dependencies"

Write-Step "Running dart pub get..."
Push-Location (Join-Path $ScriptDir "packages")
dart pub get
Pop-Location
Write-Ok "Dart dependencies installed."

# ── Step 8: Backend Code Generation ─────────────────────────────────────────

Write-Banner "Step 8: Code Generation"

Write-Step "Running build_runner for studio_backend..."
Push-Location (Join-Path $ScriptDir "packages\studio_backend")
dart run build_runner build --delete-conflicting-outputs
Pop-Location
Write-Ok "Code generation complete."

# ── Step 9: Start Supporting Services ───────────────────────────────────────

if (-not $SkipDocker -and (Test-DockerRunning)) {
    Write-Banner "Step 9: Docker Services"

    Write-Step "Starting postgres and redis..."
    docker compose up -d postgres redis
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Database and cache services started."
    } else {
        Write-Warn "Failed to start Docker services. Run manually: docker compose up -d postgres redis"
    }
} else {
    if (-not $SkipDocker) {
        Write-Warn "Docker is not running. Skipping service startup."
        Write-Host "  Start Docker Desktop and run: docker compose up -d postgres redis" -ForegroundColor White
    }
}

# ── Done ────────────────────────────────────────────────────────────────────

Write-Banner "Dev Environment Ready!"

Write-Host "  Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "  Backend:  cd packages\studio_backend; dart run bin\server.dart" -ForegroundColor White
Write-Host "  UI:       cd packages\studio_ui; flutter run -d chrome" -ForegroundColor White
Write-Host ""
Write-Host "  Build Docker images from source:" -ForegroundColor White
Write-Host "    dev.bat              Backend + UI only" -ForegroundColor Gray
Write-Host "    dev-all.bat          All services including models" -ForegroundColor Gray
Write-Host ""
Write-Host "  Supporting services:" -ForegroundColor White
Write-Host "    docker compose up -d postgres redis      Start DB + cache" -ForegroundColor Gray
Write-Host "    docker compose up -d                     Start full stack" -ForegroundColor Gray
Write-Host "    docker compose down                      Stop all services" -ForegroundColor Gray
Write-Host ""

Pop-Location
