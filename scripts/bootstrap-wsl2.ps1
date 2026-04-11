<#
.PURPOSE
Bootstrap WSL2 and Ubuntu 22.04 on Windows 10 21H1 for the AO Conductor Kit.
.AUTHOR
TODO
.DATE
2026-04-11
.TESTED ENVIRONMENT
Windows 10 Pro 21H1 build 19043
.USAGE
powershell.exe -ExecutionPolicy Bypass -File .\scripts\bootstrap-wsl2.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\bootstrap-wsl2.ps1 -InstallPath "D:\WSL"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$InstallPath = 'D:\WSL'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Write-Section { param([string]$Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host $Message -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Failure { param([string]$Message) Write-Host $Message -ForegroundColor Red }
function Exit-WithError {
    param([string]$Message, [int]$Code = 1)
    Write-Failure $Message
    exit $Code
}
function Normalize-Text {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    return ($Text -replace "`r`n", "`n").Trim()
}
function Invoke-CheckedCommand {
    param([string]$FilePath, [string[]]$ArgumentList, [string]$Description, [int[]]$AllowedExitCodes = @(0))
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow
        if ($AllowedExitCodes -notcontains $process.ExitCode) {
            throw "$Description failed with exit code $($process.ExitCode)."
        }
        return $process.ExitCode
    }
    catch {
        throw "$Description failed. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
    }
}
function Download-File {
    param([string]$Uri, [string]$OutFile, [string]$Label)
    if (Test-Path $OutFile) {
        Write-Warn "$Label already exists at $OutFile. Skipping download."
        return
    }
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
        Write-Success "Downloaded $Label to $OutFile."
    }
    catch {
        throw "Failed to download $Label from $Uri. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
    }
}
function Prompt-RebootAndExit {
    param([string]$ResumeCommand)
    Write-Warn 'A reboot is required before WSL2 setup can continue.'
    Write-Host 'Run this command after reboot:' -ForegroundColor Yellow
    Write-Host "  $ResumeCommand" -ForegroundColor Yellow
    [void](Read-Host 'Press Enter to exit cleanly, reboot Windows, and rerun the command above')
    exit 0
}
try {
    Write-Section 'Validating host'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Exit-WithError 'Administrator rights are required. Re-run this script from an elevated PowerShell prompt.'
    }

    $osInfo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $buildNumber = [int]$osInfo.CurrentBuildNumber
    if ($buildNumber -lt 19041) {
        Exit-WithError "Windows build $buildNumber is not supported. Minimum required version is Windows 10 2004 (build 19041)."
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $installRoot = $InstallPath
    $scriptPath = $MyInvocation.MyCommand.Path
    $resumeCommand = 'powershell.exe -ExecutionPolicy Bypass -File "{0}" -InstallPath "{1}"' -f $scriptPath, $installRoot
    $dismPath = Join-Path $env:WINDIR 'System32\dism.exe'
    $wslExePath = Join-Path $env:WINDIR 'System32\wsl.exe'
    $kernelMsiUrl = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
    $rootfsUrl = 'https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-ubuntu22.04lts.rootfs.tar.gz'
    $kernelMsiPath = Join-Path $installRoot 'wsl_update_x64.msi'
    $rootfsPath = Join-Path $installRoot 'ubuntu-22.04.tar.gz'
    $distroName = 'Ubuntu-22.04'
    $distroPath = Join-Path $installRoot $distroName
    $wslConfigPath = Join-Path $env:USERPROFILE '.wslconfig'
    $featureNames = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    Write-Success "Install root is $installRoot."
    Write-Section 'Checking Windows features'
    $featureStates = @{}
    foreach ($featureName in $featureNames) {
        try {
            $featureStates[$featureName] = Get-WindowsOptionalFeature -Online -FeatureName $featureName
        }
        catch {
            throw "Failed to query Windows feature state for $featureName. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
        }
    }
    if ($featureStates.Values | Where-Object { $_.State -eq 'Enable Pending' }) {
        Prompt-RebootAndExit -ResumeCommand $resumeCommand
    }
    $rebootRequired = $false
    foreach ($featureName in $featureNames) {
        $featureState = $featureStates[$featureName].State
        if ($featureState -eq 'Enabled') {
            Write-Success "$featureName is already enabled."
            continue
        }
        if ($featureState -ne 'Disabled') {
            throw "Feature $featureName is in unexpected state '$featureState'. See TROUBLESHOOTING.md."
        }
        Write-Warn "Enabling $featureName via DISM."
        $exitCode = Invoke-CheckedCommand `
            -FilePath $dismPath `
            -ArgumentList @('/online', '/enable-feature', "/featurename:$featureName", '/all', '/norestart') `
            -Description "Enabling $featureName" `
            -AllowedExitCodes @(0, 3010)
        if ($exitCode -eq 3010) { $rebootRequired = $true }
    }
    foreach ($featureName in $featureNames) {
        $featureState = (Get-WindowsOptionalFeature -Online -FeatureName $featureName).State
        if ($featureState -eq 'Enable Pending') { $rebootRequired = $true }
        elseif ($featureState -ne 'Enabled') {
            throw "Feature $featureName did not reach the Enabled state. Current state: $featureState. See TROUBLESHOOTING.md."
        }
    }
    if ($rebootRequired) {
        Prompt-RebootAndExit -ResumeCommand $resumeCommand
    }
    if (-not (Test-Path $wslExePath)) {
        Exit-WithError "wsl.exe was not found at $wslExePath after feature enablement. Reboot Windows and rerun this script. See TROUBLESHOOTING.md."
    }
    Write-Section 'Checking WSL2 kernel package'
    $kernelInstalled = $false
    try {
        $kernelInstalled = $null -ne (Get-Package | Where-Object { $_.Name -like '*Windows Subsystem for Linux Update*' })
    }
    catch {
        Write-Warn 'Get-Package check failed. Falling back to wsl.exe presence for kernel package detection.'
        $kernelInstalled = Test-Path $wslExePath
    }
    if ($kernelInstalled) {
        Write-Success 'WSL2 kernel package already appears to be installed.'
    }
    else {
        Download-File -Uri $kernelMsiUrl -OutFile $kernelMsiPath -Label 'WSL2 kernel MSI'
        Write-Warn 'Installing WSL2 kernel MSI silently.'
        [void](Invoke-CheckedCommand `
            -FilePath 'msiexec.exe' `
            -ArgumentList @('/i', $kernelMsiPath, '/quiet', '/norestart') `
            -Description 'Installing the WSL2 kernel MSI')
        Write-Success 'WSL2 kernel MSI installed.'
    }
    Write-Section 'Setting WSL default version'
    [void](Invoke-CheckedCommand `
        -FilePath $wslExePath `
        -ArgumentList @('--set-default-version', '2') `
        -Description 'Setting the default WSL version to 2')
    Write-Success 'Default WSL version is set to 2.'
    Write-Section 'Checking Ubuntu-22.04 distribution'
    try {
        $wslList = & $wslExePath -l -v 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "wsl.exe returned exit code $LASTEXITCODE."
        }
    }
    catch {
        throw "Failed to enumerate WSL distributions. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
    }
    $distributionExists = $false
    if ($wslList) {
        $distributionExists = $null -ne ($wslList | Select-String -Pattern '^\s*\*?\s*Ubuntu-22\.04\s+')
    }
    if ($distributionExists) {
        Write-Success 'Ubuntu-22.04 is already imported.'
    }
    else {
        Download-File -Uri $rootfsUrl -OutFile $rootfsPath -Label 'Ubuntu 22.04 rootfs'
        Write-Warn "Importing $distroName as WSL2 into $distroPath."
        [void](Invoke-CheckedCommand `
            -FilePath $wslExePath `
            -ArgumentList @('--import', $distroName, $distroPath, $rootfsPath, '--version', '2') `
            -Description "Importing $distroName")
        Write-Success 'Ubuntu-22.04 import completed.'
    }
    Write-Section 'Writing .wslconfig'
    $desiredWslConfig = @'
[wsl2]
memory=6GB
processors=4
swap=2GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
'@
    $existingWslConfig = $null
    if (Test-Path $wslConfigPath) { $existingWslConfig = Get-Content -Path $wslConfigPath -Raw }
    if ((Normalize-Text $existingWslConfig) -eq (Normalize-Text $desiredWslConfig)) {
        Write-Success "$wslConfigPath is already up to date."
    }
    else {
        try {
            Set-Content -Path $wslConfigPath -Value $desiredWslConfig -Encoding ASCII
            Write-Success "Wrote WSL settings to $wslConfigPath."
        }
        catch {
            throw "Failed to write $wslConfigPath. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
        }
    }
    Write-Section 'Verifying WSL state'
    try {
        $verificationOutput = & $wslExePath -l -v
        if ($LASTEXITCODE -ne 0) {
            throw "wsl.exe returned exit code $LASTEXITCODE."
        }
    }
    catch {
        throw "Failed to verify WSL distributions. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
    }
    $verificationOutput | ForEach-Object { Write-Host $_ }
    Write-Success 'WSL bootstrap completed successfully.'
}
catch {
    Exit-WithError "Bootstrap failed. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
}
