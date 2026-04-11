## Task: Write `scripts/bootstrap-wsl2.ps1`

Create a PowerShell script that installs WSL2 + Ubuntu 22.04 from scratch on Windows 10 21H1. This script is part of the AO Conductor Kit — a portable init project that lets a user get Agent Orchestrator running on a fresh Win10 machine.

## Tested facts from the 2026-04-11 install session on Windows 10 Pro build 19043

1. Win10 21H1 does NOT support the modern one-liner "wsl --install". The wsl.exe binary does not even exist before the features are enabled. Must use DISM.
2. BIOS virtualization must already be enabled (assume yes — Docker Desktop would fail otherwise).
3. Hyper-V is NOT required. Docker and WSL2 use the VirtualMachinePlatform feature, which is different from full Hyper-V.

## Exact install sequence that worked

### Step 1 — Enable Windows features (requires reboot)
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

### Step 2 — After reboot, install WSL2 kernel MSI
Download: https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi (approx 16 MB)
Save to: D:\WSL\wsl_update_x64.msi
Install silently:
    Start-Process msiexec.exe -Wait -ArgumentList "/i","D:\WSL\wsl_update_x64.msi","/quiet","/norestart"

### Step 3 — Set default WSL version
    wsl --set-default-version 2

### Step 4 — Download Ubuntu 22.04 rootfs
URL: https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz (approx 325 MB)
Save to: D:\WSL\ubuntu-22.04.tar.gz

IMPORTANT: The old filename "ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz" returns 404 as of April 2026. Canonical renamed the file. Use only the new "-ubuntu22.04lts" name.

### Step 5 — Import as WSL2 distribution
    wsl --import Ubuntu-22.04 "D:\WSL\Ubuntu-22.04" "D:\WSL\ubuntu-22.04.tar.gz" --version 2

### Step 6 — Verify
    wsl -l -v
Expect to see: Ubuntu-22.04 Stopped 2

### Step 7 — Write ~/.wslconfig
    [wsl2]
    memory=6GB
    processors=4
    swap=2GB
    localhostForwarding=true

    [experimental]
    autoMemoryReclaim=gradual
    sparseVhd=true

## Script requirements

1. Script is idempotent. Check each state before acting:
   - Check feature state via Get-WindowsOptionalFeature before DISM
   - Check MSI installed via Get-Package or by testing C:\Windows\System32\wsl.exe existence before installing
   - Check wsl -l -v output for Ubuntu-22.04 before import
2. Detect administrator rights at the top. If not admin, print hint and exit.
3. Detect Win build. If build less than 19041, exit with error explaining minimum is Win10 2004.
4. After enabling features (step 1), if a reboot is actually needed, prompt the user, print exactly which command to run after reboot, and exit cleanly with code 0.
5. All downloads must use Invoke-WebRequest with -UseBasicParsing and TLS 1.2 enforced.
6. Default D:\WSL as the target. Allow override via -InstallPath parameter.
7. Header comment block at top with: purpose, author stub, date 2026-04-11, tested env Windows 10 Pro 21H1 build 19043, usage example.
8. Use Write-Host with -ForegroundColor Cyan for section headers, Green for success, Red for errors, Yellow for warnings.
9. Wrap risky commands in try/catch with helpful error messages pointing to TROUBLESHOOTING.md.
10. Target length: 150 to 250 lines.

## Output constraints

- Create only this file: scripts/bootstrap-wsl2.ps1
- Do NOT modify README.md, math_utils.py, hello.py, agent-orchestrator.yaml, or any other existing file.
- Commit message: "feat: add bootstrap-wsl2.ps1 Windows WSL2 installer"
- Open a pull request from your worker branch to main.
