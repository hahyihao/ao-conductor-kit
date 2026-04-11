<#
.PURPOSE
Repair the WSL2 localhost forwarding workaround by reconciling the current WSL host IP with a Windows localhost service.
.AUTHOR
hahyihao (with AO-orchestrated Codex worker, 2026-04-12)
.DATE
2026-04-12
.TESTED ENVIRONMENT
Windows 10 Pro 21H1 build 19043 + WSL2 + Ubuntu-22.04
.USAGE
powershell.exe -ExecutionPolicy Bypass -File .\scripts\repair-wsl2-localhost-forwarding.ps1
powershell.exe -ExecutionPolicy Bypass -File .\scripts\repair-wsl2-localhost-forwarding.ps1 -ListenPort 8888 -ConnectPort 8888
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$DistroName = 'Ubuntu-22.04',

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$ListenPort = 7897,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$ConnectPort = 7897,

    [Parameter()]
    [string]$ConnectAddress = '127.0.0.1',

    [Parameter()]
    [string]$FirewallRuleName = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Section { param([string]$Message) Write-Information "`n=== $Message ===" -InformationAction Continue }
function Write-Success { param([string]$Message) Write-Information $Message -InformationAction Continue }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-Failure { param([string]$Message) Write-Output $Message }
function Exit-WithError {
    param([string]$Message, [int]$Code = 1)
    Write-Failure $Message
    exit $Code
}
function ConvertTo-NormalizedText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return $null }
    return ($Text -replace "`r`n", "`n").Trim()
}
function Invoke-NativeCommand {
    param([string]$FilePath, [string[]]$ArgumentList, [string]$Description, [int[]]$AllowedExitCodes = @(0))
    try {
        $output = & $FilePath @ArgumentList 2>&1
        $exitCode = $LASTEXITCODE
        if ($AllowedExitCodes -notcontains $exitCode) {
            $normalizedOutput = ConvertTo-NormalizedText (($output | Out-String))
            throw "$Description failed with exit code $exitCode. Output: $normalizedOutput"
        }
        return @($output)
    }
    catch {
        throw "$Description failed. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
    }
}
function Test-IPv4Address {
    param([AllowNull()][string]$Address)
    if ([string]::IsNullOrWhiteSpace($Address)) { return $false }
    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$parsedAddress)) { return $false }
    return $parsedAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork
}
function Test-TcpEndpoint {
    param([string]$Address, [int]$Port)
    try {
        return [bool](Test-NetConnection -ComputerName $Address -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet)
    }
    catch {
        return $false
    }
}
function Get-WslDistributionVersion {
    param([string]$WslExePath, [string]$TargetDistro)
    $wslList = Invoke-NativeCommand `
        -FilePath $WslExePath `
        -ArgumentList @('-l', '-v') `
        -Description 'Enumerating WSL distributions'
    $pattern = '^\s*\*?\s*' + [regex]::Escape($TargetDistro) + '\s+.+\s+(\d+)\s*$'
    foreach ($line in $wslList) {
        if ($line -match $pattern) {
            return [int]$Matches[1]
        }
    }
    return $null
}
function Get-WslHostAddress {
    param([string]$WslExePath, [string]$TargetDistro)
    $gatewayAddress = $null
    try {
        $gatewayOutput = & $WslExePath -d $TargetDistro -- bash -lc "ip route show default 2>/dev/null | awk '/default/ {print \$3; exit}'" 2>$null
        if ($LASTEXITCODE -eq 0 -and $gatewayOutput) {
            $gatewayAddress = ConvertTo-NormalizedText (($gatewayOutput | Select-Object -First 1) | Out-String)
        }
    }
    catch {
        $gatewayAddress = $null
    }
    if (Test-IPv4Address $gatewayAddress) {
        return $gatewayAddress
    }

    Write-Warn "Could not determine the WSL host IP from inside $TargetDistro. Falling back to Windows adapter detection."
    try {
        $candidateAddress = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.IPAddress -notlike '169.254.*' -and (
                    $_.InterfaceAlias -like 'vEthernet (WSL*' -or
                    $_.InterfaceAlias -like '*WSL*'
                )
            } |
            Sort-Object -Property SkipAsSource, InterfaceIndex, IPAddress |
            Select-Object -First 1 -ExpandProperty IPAddress
    }
    catch {
        throw "Failed to query Windows network adapters for the WSL host IP. Details: $($_.Exception.Message)"
    }
    if (-not (Test-IPv4Address $candidateAddress)) {
        throw "Unable to detect the current WSL-facing host IP. Start $TargetDistro once, then rerun this script."
    }
    return $candidateAddress
}
function Get-PortProxyRuleEntry {
    param([string]$NetshPath)
    $output = Invoke-NativeCommand `
        -FilePath $NetshPath `
        -ArgumentList @('interface', 'portproxy', 'show', 'v4tov4') `
        -Description 'Reading existing v4tov4 portproxy rules'
    $rules = @()
    foreach ($line in $output) {
        if ($line -match '^\s*([0-9\.\*]+)\s+(\d+)\s+([0-9\.]+)\s+(\d+)\s*$') {
            $rules += [pscustomobject]@{
                ListenAddress  = $Matches[1]
                ListenPort     = [int]$Matches[2]
                ConnectAddress = $Matches[3]
                ConnectPort    = [int]$Matches[4]
            }
        }
    }
    return $rules
}
function Remove-PortProxyRule {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$NetshPath, [string]$ListenAddress, [int]$ListenPort)
    $target = "${ListenAddress}:$ListenPort"
    if ($PSCmdlet.ShouldProcess($target, 'Remove portproxy rule')) {
        [void](Invoke-NativeCommand `
            -FilePath $NetshPath `
            -ArgumentList @('interface', 'portproxy', 'delete', 'v4tov4', "listenport=$ListenPort", "listenaddress=$ListenAddress") `
            -Description "Removing portproxy rule $target")
        Write-Warn "Removed stale portproxy rule $target."
    }
}
function ConvertTo-NormalizedFirewallProfile {
    param([AllowNull()][object]$ProfileScope)
    if ($null -eq $ProfileScope) { return @() }

    $profiles = @()
    foreach ($entry in $ProfileScope.ToString().Split(',')) {
        $candidate = $entry.Trim()
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $profiles += $candidate
        }
    }
    if ($profiles -contains 'Any') {
        return @('Any')
    }
    return @($profiles | Sort-Object -Unique)
}
function Test-FirewallProfileMatch {
    param([AllowNull()][object]$ExistingProfile, [string]$DesiredProfile)

    $normalizedExisting = @(ConvertTo-NormalizedFirewallProfile -ProfileScope $ExistingProfile)
    $normalizedDesired = @(ConvertTo-NormalizedFirewallProfile -ProfileScope $DesiredProfile)
    if ($normalizedExisting.Count -ne $normalizedDesired.Count) {
        return $false
    }
    foreach ($profileName in $normalizedDesired) {
        if ($normalizedExisting -notcontains $profileName) {
            return $false
        }
    }
    return $true
}
function Set-IpHelperServiceState {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    try {
        $service = Get-Service -Name 'iphlpsvc' -ErrorAction Stop
    }
    catch {
        throw "The Windows IP Helper service (iphlpsvc) is missing. portproxy cannot work without it."
    }
    if ($service.Status -eq 'Running') {
        Write-Success 'Windows IP Helper service is already running.'
        return
    }
    Write-Warn 'Starting the Windows IP Helper service because portproxy depends on it.'
    try {
        if (-not $PSCmdlet.ShouldProcess('iphlpsvc', 'Start service')) {
            return
        }
        Start-Service -Name 'iphlpsvc'
        $service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running, [TimeSpan]::FromSeconds(10))
        $service.Refresh()
    }
    catch {
        throw "Failed to start the Windows IP Helper service. Start service 'iphlpsvc' and rerun this script."
    }
    if ($service.Status -ne 'Running') {
        throw "The Windows IP Helper service did not reach the Running state. Start 'iphlpsvc' manually and rerun this script."
    }
    Write-Success 'Windows IP Helper service is running.'
}
function Set-FirewallRuleState {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$DisplayName, [int]$LocalPort, [string]$FirewallProfile)
    $existingRules = @(Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue)
    $recreateRule = $existingRules.Count -ne 1
    if (-not $recreateRule -and $existingRules.Count -eq 1) {
        $existingRule = $existingRules[0]
        $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $existingRule | Select-Object -First 1
        $profileMatches = Test-FirewallProfileMatch -ExistingProfile $existingRule.Profile -DesiredProfile $FirewallProfile
        if (
            $existingRule.Direction -ne 'Inbound' -or
            $existingRule.Action -ne 'Allow' -or
            $portFilter.Protocol -ne 'TCP' -or
            $portFilter.LocalPort -ne "$LocalPort" -or
            -not $profileMatches
        ) {
            $recreateRule = $true
        }
    }
    if ($recreateRule -and $existingRules.Count -gt 0) {
        if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Remove existing firewall rules')) {
            return
        }
        $existingRules | Remove-NetFirewallRule | Out-Null
        Write-Warn "Recreating firewall rule '$DisplayName' to match TCP $LocalPort on profile '$FirewallProfile'."
    }
    if ($recreateRule -or $existingRules.Count -eq 0) {
        if (-not $PSCmdlet.ShouldProcess($DisplayName, "Create firewall rule for TCP $LocalPort on profile '$FirewallProfile'")) {
            return
        }
        New-NetFirewallRule `
            -DisplayName $DisplayName `
            -Direction Inbound `
            -LocalPort $LocalPort `
            -Protocol TCP `
            -Action Allow `
            -Profile $FirewallProfile | Out-Null
        Write-Success "Firewall rule '$DisplayName' allows inbound TCP $LocalPort on profile '$FirewallProfile'."
        return
    }
    if (-not $PSCmdlet.ShouldProcess($DisplayName, 'Enable firewall rule')) {
        return
    }
    Enable-NetFirewallRule -DisplayName $DisplayName | Out-Null
    Write-Success "Firewall rule '$DisplayName' is already up to date."
}
function Test-WslPortReachability {
    param([string]$WslExePath, [string]$TargetDistro, [string]$ListenAddress, [int]$ListenPort)
    $bashCommand = "timeout 5 bash -lc ': </dev/tcp/$ListenAddress/$ListenPort' >/dev/null 2>&1"
    try {
        & $WslExePath -d $TargetDistro -- bash -lc $bashCommand 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

try {
    Write-Section 'Validating host'
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Exit-WithError 'Administrator rights are required. Re-run this script from an elevated PowerShell prompt.'
    }
    if ([string]::IsNullOrWhiteSpace($FirewallRuleName)) {
        $FirewallRuleName = "AO Kit WSL2 localhost forwarding $ListenPort"
    }
    if (-not (Test-IPv4Address $ConnectAddress)) {
        Exit-WithError "ConnectAddress '$ConnectAddress' is not a valid IPv4 address. This script only manages v4tov4 rules."
    }
    $wslExePath = Join-Path $env:WINDIR 'System32\wsl.exe'
    $netshPath = Join-Path $env:WINDIR 'System32\netsh.exe'
    if (-not (Test-Path $wslExePath)) {
        Exit-WithError "wsl.exe was not found at $wslExePath. Run scripts/bootstrap-wsl2.ps1 first, then rerun this repair."
    }
    if (-not (Test-Path $netshPath)) {
        Exit-WithError "netsh.exe was not found at $netshPath. This Windows installation is missing a required networking tool."
    }
    $wslVersion = Get-WslDistributionVersion -WslExePath $wslExePath -TargetDistro $DistroName
    if ($null -eq $wslVersion) {
        Exit-WithError "WSL distribution '$DistroName' was not found. Run scripts/bootstrap-wsl2.ps1 first, then rerun this repair."
    }
    if ($wslVersion -ne 2) {
        Exit-WithError "'$DistroName' is registered as WSL$wslVersion. This repair only supports WSL2."
    }
    Write-Success "$DistroName is registered as WSL2."

    Write-Section 'Checking Windows localhost target'
    if (-not (Test-TcpEndpoint -Address $ConnectAddress -Port $ConnectPort)) {
        Exit-WithError "Nothing is listening on ${ConnectAddress}:$ConnectPort. Start the Windows proxy first or rerun with the correct -ConnectAddress/-ConnectPort."
    }
    Write-Success "${ConnectAddress}:$ConnectPort is reachable from Windows."

    Write-Section 'Preparing Windows networking prerequisites'
    Set-IpHelperServiceState

    Write-Section 'Detecting current WSL host address'
    $listenAddress = Get-WslHostAddress -WslExePath $wslExePath -TargetDistro $DistroName
    Write-Success "Current WSL-facing Windows host IP is $listenAddress."

    Write-Section 'Reconciling portproxy rule'
    $firewallProfile = 'Any'
    $rules = Get-PortProxyRuleEntry -NetshPath $netshPath
    $exactRule = $rules | Where-Object {
        $_.ListenAddress -eq $listenAddress -and
        $_.ListenPort -eq $ListenPort -and
        $_.ConnectAddress -eq $ConnectAddress -and
        $_.ConnectPort -eq $ConnectPort
    } | Select-Object -First 1
    $conflictingRules = $rules | Where-Object {
        $_.ListenAddress -eq $listenAddress -and
        $_.ListenPort -eq $ListenPort -and -not (
            $_.ListenAddress -eq $listenAddress -and
            $_.ListenPort -eq $ListenPort -and
            $_.ConnectAddress -eq $ConnectAddress -and
            $_.ConnectPort -eq $ConnectPort
        )
    }
    foreach ($rule in ($conflictingRules | Sort-Object -Property ListenAddress, ListenPort -Unique)) {
        Remove-PortProxyRule -NetshPath $netshPath -ListenAddress $rule.ListenAddress -ListenPort $rule.ListenPort
    }
    if ($null -eq $exactRule) {
        [void](Invoke-NativeCommand `
            -FilePath $netshPath `
            -ArgumentList @(
                'interface', 'portproxy', 'add', 'v4tov4',
                "listenport=$ListenPort",
                "listenaddress=$listenAddress",
                "connectport=$ConnectPort",
                "connectaddress=$ConnectAddress"
            ) `
            -Description "Creating portproxy rule ${listenAddress}:$ListenPort -> ${ConnectAddress}:$ConnectPort")
        Write-Success "Configured portproxy rule ${listenAddress}:$ListenPort -> ${ConnectAddress}:$ConnectPort."
    }
    else {
        Write-Success 'Portproxy rule already matches the current WSL host IP.'
    }

    Write-Section 'Reconciling firewall rule'
    Set-FirewallRuleState -DisplayName $FirewallRuleName -LocalPort $ListenPort -FirewallProfile $firewallProfile

    Write-Section 'Verifying from WSL'
    $finalRule = Get-PortProxyRuleEntry -NetshPath $netshPath | Where-Object {
        $_.ListenAddress -eq $listenAddress -and
        $_.ListenPort -eq $ListenPort -and
        $_.ConnectAddress -eq $ConnectAddress -and
        $_.ConnectPort -eq $ConnectPort
    } | Select-Object -First 1
    if ($null -eq $finalRule) {
        throw "The expected portproxy rule ${listenAddress}:$ListenPort -> ${ConnectAddress}:$ConnectPort was not present after repair."
    }
    if (-not (Test-WslPortReachability -WslExePath $wslExePath -TargetDistro $DistroName -ListenAddress $listenAddress -ListenPort $ListenPort)) {
        throw "WSL still could not reach ${listenAddress}:$ListenPort after repair. Recheck your Windows proxy process and local firewall rules."
    }
    Write-Success "WSL can reach ${listenAddress}:$ListenPort."
    Write-Output ("{0}:{1} -> {2}:{3}" -f $finalRule.ListenAddress, $finalRule.ListenPort, $finalRule.ConnectAddress, $finalRule.ConnectPort)
    Write-Success 'WSL localhost forwarding repair completed successfully.'
}
catch {
    Exit-WithError "Repair failed. See TROUBLESHOOTING.md. Details: $($_.Exception.Message)"
}
