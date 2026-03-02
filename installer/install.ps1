#Requires -RunAsAdministrator
<#
.SYNOPSIS
    studio///diskrot -- Windows Installer
.DESCRIPTION
    Installs all prerequisites for studio///diskrot:
      - WSL 2
      - Docker Desktop
      - NVIDIA GPU drivers (if GPU detected)
      - NVIDIA Container Toolkit (via WSL)
      - Project configuration (.env)
      - Docker image pull and stack launch
    Also provides update functionality via -Update flag.

    One-liner install (run in an elevated PowerShell):
      irm https://raw.githubusercontent.com/diskrot/studio/stable/installer/install.ps1 -OutFile $env:TEMP\diskrot-install.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\diskrot-install.ps1
.PARAMETER Update
    Pull latest Docker images and restart the stack.
.PARAMETER Uninstall
    Stop containers and optionally remove data volumes.
.PARAMETER GpuMode
    Force GPU mode: "auto" (detect), "cuda", or "cpu". Default: auto.
.PARAMETER SkipNvidia
    Skip NVIDIA driver installation even if a GPU is detected.
.PARAMETER InstallDir
    Override the install/project directory. Default: current directory or repo root.
#>
[CmdletBinding()]
param(
    [switch]$Update,
    [switch]$Uninstall,
    [ValidateSet("auto", "cuda", "cpu")]
    [string]$GpuMode = "auto",
    [switch]$SkipNvidia,
    [string]$InstallDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# --- Constants ----------------------------------------------------------------
$DOCKER_DESKTOP_URL  = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$NVIDIA_DRIVER_URL   = "https://www.nvidia.com/Download/index.aspx"
$MIN_NVIDIA_DRIVER   = 526
$MIN_DOCKER_VERSION  = "4.18"
$STUDIO_REPO         = "https://github.com/diskrot/studio.git"
$STUDIO_COMPOSE_FILE = if ($env:COMPOSE_FILE) { $env:COMPOSE_FILE } else { "docker-compose.yml" }

# --- Helpers ------------------------------------------------------------------

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

function Get-NvidiaDriverVersion {
    try {
        $out = & nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) {
            return [version]$out.Trim()
        }
    } catch {}
    return $null
}

function Test-WslInstalled {
    try {
        $result = wsl --status 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-WslDistroInstalled {
    try {
        $distros = wsl --list --quiet 2>&1
        return ($LASTEXITCODE -eq 0 -and $distros -and $distros.Count -gt 0)
    } catch {
        return $false
    }
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

function Invoke-DockerComposePull {
    param([int]$MaxAttempts = 3)
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        if ($attempt -gt 1) {
            Write-Warn "Pull attempt $($attempt - 1) failed. Retrying ($attempt/$MaxAttempts)..."
            Start-Sleep -Seconds 5
        }
        docker compose pull
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        $attempt++
    }
    return $false
}

function Request-Reboot {
    param([string]$Reason)
    Write-Banner "REBOOT REQUIRED"
    Write-Host "  $Reason" -ForegroundColor White
    Write-Host ""
    Write-Host "  After rebooting, re-run this installer to continue." -ForegroundColor White
    Write-Host ""
    $answer = Read-Host -Prompt "Reboot now? (Y/n)"
    if ($answer -ne "n" -and $answer -ne "N") {
        Restart-Computer -Force
    }
    exit 0
}

# --- Resolve project directory ------------------------------------------------

function Get-ProjectDir {
    if ($InstallDir) {
        return $InstallDir
    }
    # If we are inside the installer/ folder, go up one level
    $scriptDir = Split-Path -Parent $PSCommandPath
    $parentDir = Split-Path -Parent $scriptDir
    if (Test-Path (Join-Path $parentDir $STUDIO_COMPOSE_FILE)) {
        return $parentDir
    }
    # If compose file is in the current directory
    if (Test-Path (Join-Path $PWD $STUDIO_COMPOSE_FILE)) {
        return $PWD.Path
    }
    # Default to user's home
    return Join-Path $env:USERPROFILE "diskrot-studio"
}

# ==============================================================================
#  UPDATE MODE
# ==============================================================================

function Invoke-Update {
    Write-Banner "studio///diskrot -- Update"
    $projectDir = Get-ProjectDir
    if (-not (Test-Path (Join-Path $projectDir $STUDIO_COMPOSE_FILE))) {
        Write-Fail "Cannot find $STUDIO_COMPOSE_FILE in $projectDir"
        Write-Host "  Run the installer first, or specify -InstallDir." -ForegroundColor Gray
        exit 1
    }

    Push-Location $projectDir
    try {
        # Pull latest repo changes if it is a git repo
        if (Test-Path ".git") {
            Write-Step "Pulling latest repository changes..."
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Git pull failed -- continuing with image update."
            } else {
                Write-Ok "Repository updated."
            }
        }

        Write-Step "Pulling latest Docker images..."
        if (-not (Invoke-DockerComposePull -MaxAttempts 3)) {
            Write-Fail "Docker compose pull failed after 3 attempts."
            exit 1
        }
        Write-Ok "Images pulled."

        Write-Step "Restarting the stack..."
        docker compose up -d
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Docker compose up failed."
            exit 1
        }
        Write-Ok "Stack restarted."

        Write-Step "Pruning old images..."
        docker image prune -f
        Write-Ok "Cleanup complete."

        Write-Banner "Update Complete"
        Write-Host "  Studio is running at: http://localhost:3000" -ForegroundColor White
        Write-Host ""
        Start-Process "http://localhost:3000"
    } finally {
        Pop-Location
    }
}

# ==============================================================================
#  UNINSTALL MODE
# ==============================================================================

function Invoke-Uninstall {
    Write-Banner "studio///diskrot -- Uninstall"
    $projectDir = Get-ProjectDir
    if (-not (Test-Path (Join-Path $projectDir $STUDIO_COMPOSE_FILE))) {
        Write-Fail "Cannot find $STUDIO_COMPOSE_FILE in $projectDir"
        exit 1
    }

    Push-Location $projectDir
    try {
        Write-Step "Stopping all containers..."
        docker compose down
        Write-Ok "Containers stopped."

        $answer = Read-Host -Prompt "Remove Docker volumes (database + model cache)? This DELETES all data. (y/N)"
        if ($answer -eq "y" -or $answer -eq "Y") {
            Write-Step "Removing volumes..."
            docker compose down -v
            Write-Ok "Volumes removed."
        }

        Write-Step "Pruning unused images..."
        docker image prune -f
        Write-Ok "Cleanup complete."

        Write-Banner "Uninstall Complete"
        Write-Host "  Docker Desktop, WSL, and NVIDIA drivers were NOT removed." -ForegroundColor Gray
        Write-Host "  Remove them manually via Settings > Apps if desired." -ForegroundColor Gray
    } finally {
        Pop-Location
    }
}

# ==============================================================================
#  MAIN INSTALLER
# ==============================================================================

function Invoke-Install {
    Write-Banner "studio///diskrot -- Windows Installer"

    $needsReboot = $false
    $projectDir  = Get-ProjectDir

    # -- Step 1: Detect GPU ----------------------------------------------------
    Write-Banner "Step 1: GPU Detection"

    $hasNvidiaGpu = $false
    $useGpu       = $false
    $gpu          = Get-NvidiaGpu

    if ($gpu) {
        $hasNvidiaGpu = $true
        Write-Ok "NVIDIA GPU detected: $($gpu.Name)"
    } else {
        Write-Warn "No NVIDIA GPU detected. Will use CPU mode."
    }

    if ($GpuMode -eq "auto") {
        $useGpu = $hasNvidiaGpu
    } elseif ($GpuMode -eq "cuda") {
        if (-not $hasNvidiaGpu) {
            Write-Warn "CUDA mode requested but no NVIDIA GPU found. Falling back to CPU."
            $useGpu = $false
        } else {
            $useGpu = $true
        }
    } else {
        $useGpu = $false
    }

    if ($useGpu) {
        Write-Ok "Mode: GPU (CUDA)"
    } else {
        Write-Ok "Mode: CPU"
    }

    # -- Step 2: NVIDIA Drivers ------------------------------------------------
    if ($useGpu -and -not $SkipNvidia) {
        Write-Banner "Step 2: NVIDIA Drivers"

        $driverVer = Get-NvidiaDriverVersion
        if ($driverVer) {
            Write-Ok "NVIDIA driver version: $driverVer"
            if ($driverVer.Major -ge $MIN_NVIDIA_DRIVER) {
                Write-Ok "Driver meets minimum requirement (>= $MIN_NVIDIA_DRIVER)."
            } else {
                Write-Warn "Driver version $driverVer is below minimum ($MIN_NVIDIA_DRIVER)."
                Write-Step "Attempting to update NVIDIA drivers via winget..."

                if (Test-CommandExists winget) {
                    Write-Step "Searching for NVIDIA driver package..."
                    try {
                        winget install --id "Nvidia.GeForceExperience" --accept-package-agreements --accept-source-agreements
                        if ($LASTEXITCODE -eq 0) {
                            Write-Ok "NVIDIA GeForce Experience installed. Use it to update drivers."
                            $needsReboot = $true
                        } else {
                            throw "winget install failed"
                        }
                    } catch {
                        Write-Warn "Automatic driver install failed."
                        Write-Host "  Please update your NVIDIA drivers manually:" -ForegroundColor White
                        Write-Host "  $NVIDIA_DRIVER_URL" -ForegroundColor Cyan
                        Write-Host ""
                        Read-Host -Prompt "Press Enter after installing drivers to continue"
                    }
                } else {
                    Write-Warn "winget not available. Please install NVIDIA drivers manually:"
                    Write-Host "  $NVIDIA_DRIVER_URL" -ForegroundColor Cyan
                    Read-Host -Prompt "Press Enter after installing drivers to continue"
                }
            }
        } else {
            Write-Warn "NVIDIA drivers not installed or nvidia-smi not found."
            Write-Step "Attempting to install NVIDIA drivers..."

            if (Test-CommandExists winget) {
                try {
                    winget install --id "Nvidia.GeForceExperience" --accept-package-agreements --accept-source-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-Ok "NVIDIA GeForce Experience installed."
                        Write-Host "  Open GeForce Experience to download the latest Game Ready driver." -ForegroundColor White
                        $needsReboot = $true
                    } else {
                        throw "winget install failed"
                    }
                } catch {
                    Write-Warn "Automatic install failed. Please install drivers manually:"
                    Write-Host "  $NVIDIA_DRIVER_URL" -ForegroundColor Cyan
                    Read-Host -Prompt "Press Enter after installing drivers to continue"
                }
            } else {
                Write-Warn "winget not available. Please install NVIDIA drivers manually:"
                Write-Host "  $NVIDIA_DRIVER_URL" -ForegroundColor Cyan
                Read-Host -Prompt "Press Enter after installing drivers to continue"
            }
        }
    } else {
        Write-Step "Skipping NVIDIA driver setup (CPU mode or -SkipNvidia)."
    }

    # -- Step 3: WSL 2 ---------------------------------------------------------
    Write-Banner "Step 3: WSL 2"

    if (Test-WslInstalled) {
        Write-Ok "WSL is installed."
    } else {
        Write-Step "Installing WSL 2..."
        wsl --install --no-distribution
        $needsReboot = $true
        Write-Ok "WSL 2 installation initiated."
    }

    # Ensure a distro is present
    if (Test-WslDistroInstalled) {
        Write-Ok "WSL distro found."
    } else {
        Write-Step "Installing Ubuntu WSL distro..."
        wsl --install -d Ubuntu --no-launch
        $needsReboot = $true
        Write-Ok "Ubuntu distro installation initiated."
    }

    if ($needsReboot) {
        Request-Reboot "WSL 2 and/or NVIDIA drivers were installed and require a reboot."
    }

    # -- Step 4: Docker Desktop ------------------------------------------------
    Write-Banner "Step 4: Docker Desktop"

    if (Test-CommandExists docker) {
        Write-Ok "Docker CLI found."

        # Check if Docker Desktop is running
        if (Test-DockerRunning) {
            Write-Ok "Docker Desktop is running."
        } else {
            Write-Step "Starting Docker Desktop..."
            $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerPath) {
                Start-Process $dockerPath
                if (-not (Wait-ForDocker -TimeoutSeconds 120)) {
                    Write-Fail "Docker Desktop did not start within 120 seconds."
                    Write-Host "  Please start Docker Desktop manually and re-run the installer." -ForegroundColor White
                    exit 1
                }
            } else {
                Write-Fail "Docker Desktop executable not found at expected path."
                Write-Host "  Please start Docker Desktop manually and re-run the installer." -ForegroundColor White
                exit 1
            }
        }
    } else {
        Write-Step "Docker not found. Installing Docker Desktop..."

        if (Test-CommandExists winget) {
            Write-Step "Installing via winget..."
            winget install --id "Docker.DockerDesktop" --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Docker Desktop installed via winget."
            } else {
                Write-Warn "winget installation failed. Downloading installer directly..."
                $installerPath = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
                Write-Step "Downloading Docker Desktop installer..."
                Invoke-WebRequest -Uri $DOCKER_DESKTOP_URL -OutFile $installerPath -UseBasicParsing
                Write-Step "Running Docker Desktop installer (this may take a few minutes)..."
                Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait
                Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
                Write-Ok "Docker Desktop installed."
            }
        } else {
            $installerPath = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
            Write-Step "Downloading Docker Desktop installer..."
            Invoke-WebRequest -Uri $DOCKER_DESKTOP_URL -OutFile $installerPath -UseBasicParsing
            Write-Step "Running Docker Desktop installer (this may take a few minutes)..."
            Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet", "--accept-license" -Wait
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            Write-Ok "Docker Desktop installed."
        }

        # Refresh PATH so docker CLI is available
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                     [System.Environment]::GetEnvironmentVariable("Path", "User")

        Write-Step "Starting Docker Desktop..."
        $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerPath) {
            Start-Process $dockerPath
        }

        if (-not (Wait-ForDocker -TimeoutSeconds 180)) {
            Write-Warn "Docker Desktop is not responding yet."
            Write-Host "  A reboot may be needed for Docker Desktop to work properly." -ForegroundColor White
            Request-Reboot "Docker Desktop was just installed and may need a reboot."
        }
    }

    # Enable WSL 2 backend in Docker Desktop settings if possible
    Write-Step "Verifying Docker is using WSL 2 backend..."
    $dockerInfo = docker info 2>$null
    if ($dockerInfo -match "WSL") {
        Write-Ok "Docker is using WSL 2 backend."
    } else {
        Write-Warn "Could not confirm WSL 2 backend. Please ensure 'Use the WSL 2 based engine' is enabled"
        Write-Host "  in Docker Desktop > Settings > General." -ForegroundColor White
    }

    # -- Step 5: Project Setup -------------------------------------------------
    Write-Banner "Step 5: Project Setup"

    if (-not (Test-Path (Join-Path $projectDir $STUDIO_COMPOSE_FILE))) {
        # Need to clone the repo
        if (Test-CommandExists git) {
            Write-Step "Cloning studio///diskrot to $projectDir..."
            git clone -b stable $STUDIO_REPO $projectDir
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "Git clone failed."
                exit 1
            }
            Write-Ok "Repository cloned."
        } else {
            Write-Fail "git is not installed and the project is not at $projectDir."
            Write-Host "  Install git (winget install Git.Git) and re-run or clone the repo manually." -ForegroundColor White
            exit 1
        }
    } else {
        Write-Ok "Project found at $projectDir"
    }

    # Create data directories
    $dataDirs = @(
        "data/acestep-checkpoints",
        "data/acestep-output",
        "data/yulan-hf-cache",
        "data/yulan-gguf"
    )
    foreach ($dir in $dataDirs) {
        $fullPath = Join-Path $projectDir $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }
    Write-Ok "Data directories ready."

    # -- Step 6: Environment Configuration -------------------------------------
    Write-Banner "Step 6: Environment Configuration"

    $envFile = Join-Path $projectDir ".env"
    $writeEnv = $false
    if (Test-Path $envFile) {
        Write-Ok ".env file already exists."
        $answer = Read-Host -Prompt "Overwrite .env with fresh defaults? (y/N)"
        if ($answer -eq "y" -or $answer -eq "Y") {
            $writeEnv = $true
        } else {
            Write-Step "Keeping existing .env file."
        }
    } else {
        $writeEnv = $true
    }

    if ($writeEnv) {
        $variant = if ($useGpu) { "cuda" } else { "cpu" }
        $composeLine = if ($useGpu) {
            "COMPOSE_FILE=docker-compose.yml;docker-compose.gpu.yml"
        } else {
            "COMPOSE_FILE=docker-compose.yml"
        }

        # Prompt for Hugging Face token
        Write-Host ""
        Write-Host "  A Hugging Face token is required to download AI model weights." -ForegroundColor White
        Write-Host "  Create one at: https://huggingface.co/settings/tokens" -ForegroundColor Cyan
        Write-Host "  (select 'Read' access)" -ForegroundColor DarkGray
        Write-Host ""
        $hfToken = Read-Host -Prompt "  Hugging Face token (hf_...)"
        if (-not $hfToken) {
            Write-Warn "No token entered. Model downloads may fail without a valid token."
            Write-Host "  You can set HF_TOKEN later in the .env file." -ForegroundColor Gray
        } else {
            Write-Ok "Hugging Face token saved."
        }

        $envLines = @(
            "POSTGRES_USER=studio",
            "POSTGRES_PASSWORD=studio",
            "POSTGRES_DB=studio",
            "POSTGRES_PORT=5432",
            "",
            "REDIS_PORT=6379",
            "",
            "PGADMIN_DEFAULT_EMAIL=admin@diskrot.studio",
            "PGADMIN_DEFAULT_PASSWORD=admin",
            "PGADMIN_PORT=5050",
            "",
            "REDISINSIGHT_PORT=5540",
            "",
            "BACKEND_PORT=8080",
            "UI_PORT=3000",
            "BUILD_ENV=local",
            "",
            "# ACE-Step: `"cuda`" for GPU, `"cpu`" for CPU-only",
            "ACESTEP_VARIANT=$variant",
            "# YuLan-Mini: `"cuda`" for GPU, `"cpu`" for CPU-only",
            "YULAN_VARIANT=$variant",
            "# GPU compose overlay (semicolon separator on Windows)",
            "$composeLine",
            "# Hugging Face token for model downloads (get one at https://huggingface.co/settings/tokens)",
            "HF_TOKEN=$hfToken"
        )
        $envContent = $envLines -join "`r`n"
        Set-Content -Path $envFile -Value $envContent -Encoding UTF8
        Write-Ok ".env configured (mode: $variant)."
    }

    # -- Step 7: Pull Images and Launch ----------------------------------------
    Write-Banner "Step 7: Pull Images and Launch"

    Push-Location $projectDir
    try {
        Write-Step "Pulling Docker images (this may take a while on first run)..."
        if (-not (Invoke-DockerComposePull -MaxAttempts 5)) {
            Write-Fail "Docker compose pull failed after 5 attempts."
            Write-Host "  Check your internet connection and Docker Desktop status." -ForegroundColor White
            exit 1
        }
        Write-Ok "All images pulled."

        Write-Step "Starting the stack..."
        docker compose up -d
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Docker compose up failed."
            exit 1
        }
        Write-Ok "Stack is starting up."

        Write-Step "Pruning old images..."
        docker image prune -f
    } finally {
        Pop-Location
    }

    # -- Step 8: Create Shortcuts ----------------------------------------------
    Write-Banner "Step 8: Desktop Shortcuts"

    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $installerScript = $PSCommandPath

    # Studio launch shortcut
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $desktopPath "diskrot studio.lnk"))
        $shortcut.TargetPath = "http://localhost:3000"
        $shortcut.IconLocation = "shell32.dll,13"
        $shortcut.Description = "Open studio///diskrot in browser"
        $shortcut.Save()
        Write-Ok "Desktop shortcut created: diskrot studio"
    } catch {
        Write-Warn "Could not create browser shortcut: $_"
    }

    # Update shortcut — always point to the installer inside the repo so it works
    # even when the initial install was run from a temp directory.
    $repoInstaller = Join-Path $projectDir "installer\install.ps1"
    $shortcutTarget = if (Test-Path $repoInstaller) { $repoInstaller } else { $installerScript }
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path $desktopPath "diskrot studio - Update.lnk"))
        $shortcut.TargetPath = "powershell.exe"
        $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$shortcutTarget`" -Update"
        $shortcut.WorkingDirectory = $projectDir
        $shortcut.IconLocation = "shell32.dll,46"
        $shortcut.Description = "Update studio///diskrot to latest version"
        $shortcut.Save()
        Write-Ok "Desktop shortcut created: diskrot studio - Update"
    } catch {
        Write-Warn "Could not create update shortcut: $_"
    }

    # -- Done ------------------------------------------------------------------
    Write-Banner "Installation Complete!"

    Write-Host "  studio///diskrot is starting up." -ForegroundColor White
    Write-Host ""
    Write-Host "  First startup downloads AI model weights and may take several minutes." -ForegroundColor Gray
    Write-Host "  Subsequent starts are fast (models are cached locally)." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Studio UI:     http://localhost:3000" -ForegroundColor White
    Write-Host "  pgAdmin:       http://localhost:5050" -ForegroundColor DarkGray
    Write-Host "  RedisInsight:  http://localhost:5540" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  To update later:  double-click start.bat (or .\installer\install.ps1 -Update)" -ForegroundColor White
    Write-Host "  To stop:          docker compose down" -ForegroundColor White
    Write-Host "  To uninstall:     .\installer\install.ps1 -Uninstall" -ForegroundColor White
    Write-Host ""

    # Open browser
    Start-Process "http://localhost:3000"
}

# ==============================================================================
#  AUTO-DETECT: is this a fresh install or an update?
# ==============================================================================

function Test-AlreadyInstalled {
    # Already installed if: docker is available, docker is running, and
    # the project .env exists (meaning we ran the installer before).
    if (-not (Test-CommandExists docker)) { return $false }
    if (-not (Test-DockerRunning))        { return $false }
    $projectDir = Get-ProjectDir
    $envFile = Join-Path $projectDir ".env"
    if (-not (Test-Path $envFile))        { return $false }
    return $true
}

# ==============================================================================
#  ENTRY POINT
# ==============================================================================

if ($Update) {
    Invoke-Update
} elseif ($Uninstall) {
    Invoke-Uninstall
} else {
    # Auto-detect: if everything is already set up, do an update instead
    if (Test-AlreadyInstalled) {
        Write-Banner "Existing installation detected"
        Write-Host "  Docker is running and .env exists -- switching to update mode." -ForegroundColor White
        Write-Host ""
        Invoke-Update
    } else {
        Invoke-Install
    }
}
