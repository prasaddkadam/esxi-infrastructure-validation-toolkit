# VMware ESXi Infrastructure Health & Validation Toolkit
# Purpose: Run a read-only, isolated ESXi audit from the five existing scripts.
# Requires: PowerShell 7 and VMware PowerCLI.
# No VM lifecycle operations or vSphere API writes are performed.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ESXiServer,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VMName,

    [string]$OutputDirectory,

    [ValidateRange(1, 720)]
    [int]$MaxNICSnapshotAgeHours = 48
)

$ErrorActionPreference = 'Stop'

if (-not $OutputDirectory) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    $WorkspaceRoot = Split-Path -Parent $RepoRoot
    $OutputDirectory = Join-Path $WorkspaceRoot 'output'
}

# Keep all generated reports outside source control by default.
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

# A stable, non-identifying directory key prevents NIC snapshots from
# different ESXi hosts being compared with one another.
$ServerBytes = [Text.Encoding]::UTF8.GetBytes($ESXiServer.Trim().ToLowerInvariant())
$Hasher = [Security.Cryptography.SHA256]::Create()
try {
    $ServerHash = $Hasher.ComputeHash($ServerBytes)
}
finally {
    $Hasher.Dispose()
}
$HostKey = ([BitConverter]::ToString($ServerHash) -replace '-', '').Substring(0, 16).ToLowerInvariant()

$HostDirectory = Join-Path (Join-Path $OutputDirectory 'history') $HostKey
$LastNICFile = Join-Path $HostDirectory 'latest-NIC.csv'
$RunName = 'audit-{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$RunDirectory = Join-Path (Join-Path $OutputDirectory 'runs') (Join-Path $HostKey $RunName)

New-Item -ItemType Directory -Path $RunDirectory -Force | Out-Null

$ScriptDirectory = $PSScriptRoot
$InventoryScript = Join-Path $ScriptDirectory '01-Get-VMInventory.ps1'
$HealthScript = Join-Path $ScriptDirectory '02-Get-ESXiHostHealth.ps1'
$CompareScript = Join-Path $ScriptDirectory '03-Compare-NICHealth.ps1'
$BaselineScript = Join-Path $ScriptDirectory '04-Test-LabBaseline.ps1'
$ReportScript = Join-Path $ScriptDirectory '05-Get-LabReport.ps1'

foreach ($Script in @($InventoryScript, $HealthScript, $CompareScript, $BaselineScript, $ReportScript)) {
    if (-not (Test-Path -LiteralPath $Script -PathType Leaf)) {
        throw "Required audit script not found: $Script"
    }
}

Write-Host "`n=== ESXi AUDIT RUN ===" -ForegroundColor Cyan
Write-Host "Run directory: $RunDirectory"
Write-Host "Target VM: $VMName"
Write-Host "Operations: Read-only"

try {
    # Reuse the current VIServer connection when already established.
    $Connection = $global:DefaultVIServers |
        Where-Object { $_.Name -eq $ESXiServer -and $_.IsConnected } |
        Select-Object -First 1

    if (-not $Connection) {
        $Connection = Connect-VIServer -Server $ESXiServer -ErrorAction Stop
    }

    if (-not $Connection -or -not $Connection.IsConnected) {
        throw "Could not establish a connected ESXi session."
    }

    Write-Host "`n[1/5] VM inventory"
    & $InventoryScript -ESXiServer $ESXiServer -OutputDirectory $RunDirectory

    Write-Host "`n[2/5] Host, datastore and NIC health"
    & $HealthScript -ESXiServer $ESXiServer -OutputDirectory $RunDirectory

    $NewNICFile = Get-ChildItem -LiteralPath $RunDirectory -Filter 'ESXi-NICHealth-*.csv' -File |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $NewNICFile) {
        throw 'NIC health collector did not generate a snapshot.'
    }

    Write-Host "`n[3/5] NIC error comparison"
    $ComparisonPossible = $false

    if (Test-Path -LiteralPath $LastNICFile -PathType Leaf) {
        try {
            $OldRow = Import-Csv -LiteralPath $LastNICFile |
                Select-Object -First 1
            $NewRow = Import-Csv -LiteralPath $NewNICFile.FullName |
                Select-Object -First 1

            if (-not $OldRow -or -not $NewRow) {
                throw 'NIC snapshot contains no records.'
            }

            $Format = 'yyyy-MM-dd HH:mm:ss'
            $Culture = [Globalization.CultureInfo]::InvariantCulture
            $OldTime = [datetime]::ParseExact($OldRow.Timestamp, $Format, $Culture)
            $NewTime = [datetime]::ParseExact($NewRow.Timestamp, $Format, $Culture)
            $Age = $NewTime - $OldTime

            if ($Age.TotalSeconds -le 0) {
                Write-Warning 'Previous NIC snapshot is not older than the current snapshot; comparison skipped.'
            }
            elseif ($Age.TotalHours -gt $MaxNICSnapshotAgeHours) {
                Write-Warning 'Previous NIC snapshot is too old; comparison skipped.'
            }
            else {
                $PreviousNICName = 'ESXi-NICHealth-{0}.csv' -f $OldTime.ToString('yyyyMMdd-HHmmss-fff')
                $PreviousNICPath = Join-Path $RunDirectory $PreviousNICName
                Copy-Item -LiteralPath $LastNICFile -Destination $PreviousNICPath -ErrorAction Stop
                $ComparisonPossible = $true
            }
        }
        catch {
            Write-Warning "NIC history could not be used: $($_.Exception.Message)"
        }
    }

    if ($ComparisonPossible) {
        & $CompareScript -OutputDirectory $RunDirectory
    }
    else {
        Write-Host 'No usable previous NIC snapshot. Network comparison will be UNKNOWN for this run.'
    }

    Write-Host "`n[4/5] Expected configuration baseline"
    & $BaselineScript -ESXiServer $ESXiServer -VMName $VMName -OutputDirectory $RunDirectory

    Write-Host "`n[5/5] Consolidated audit report"
    & $ReportScript -OutputDirectory $RunDirectory

    $ReportFile = Get-ChildItem -LiteralPath $RunDirectory -Filter 'ESXi-LabReport-*.csv' -File |
        Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ReportFile) {
        throw 'Consolidated audit report was not produced.'
    }

    # Preserve only the latest completed NIC snapshot per host. It must never be
    # promoted after a failed run, which would make subsequent deltas misleading.
    New-Item -ItemType Directory -Path $HostDirectory -Force | Out-Null
    Copy-Item -LiteralPath $NewNICFile.FullName -Destination $LastNICFile -Force

    $ReportRows = @(Import-Csv -LiteralPath $ReportFile.FullName)
    $Statuses = @($ReportRows | Select-Object -ExpandProperty Status)
    $Overall = if ('FAIL' -in $Statuses) { 'FAIL' }
        elseif ('UNKNOWN' -in $Statuses) { 'UNKNOWN' }
        elseif ('WARNING' -in $Statuses) { 'WARNING' }
        else { 'PASS' }

    Write-Host "`n=== AUDIT COMPLETE ===" -ForegroundColor Cyan
    Write-Host "Overall: $Overall"
    Write-Host "Report: $($ReportFile.FullName)"
    Write-Host "Output directory: $RunDirectory"
}
catch {
    Write-Warning "Audit did not complete successfully. Partial outputs (if any) are in $RunDirectory. $($_.Exception.Message)"
    throw
}
