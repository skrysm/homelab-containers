#!/usr/bin/env pwsh

#
# Determines the container image version from the installed Unbound application.
#

param (
    [string] $Image = "homelab-unbound:local"
)

# Stop on every error
$script:ErrorActionPreference = 'Stop'

$versionOutput = docker run --rm $Image unbound -V
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to run 'unbound -V' in image '$Image'. Docker exited with code $LASTEXITCODE.`n$versionOutput"
}

Write-Host -ForegroundColor DarkGray "Checking output for version..."
Write-Host

$version = $null
$line = 1
foreach ($versionOutputLine in $versionOutput) {
    Write-Host -ForegroundColor DarkGray "Checking line $($line): $versionOutputLine"
    $line++
    if ($versionOutputLine -match "^Version\s+([0-9][^\s]*)") {
        $version = $Matches[1]
        Write-Host
        Write-Host -ForegroundColor DarkGray "Detected version: $version"
        Write-Host
        break
    }
}

if (-not $version) {
    Write-Error "Failed to detect Unbound version from image '$Image'."
}

$version
