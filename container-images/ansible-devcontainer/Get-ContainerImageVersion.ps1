#!/usr/bin/env pwsh

#
# Determines the container image version from the installed Ansible package.
#

param (
    [string] $Image = "ansible-devcontainer:local"
)

# Stop on every error
$script:ErrorActionPreference = 'Stop'

$pythonScript = @'
import importlib.metadata

print(importlib.metadata.version("ansible"))
'@

$versionOutput = docker run --rm $Image python3 -c $pythonScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to detect the ansible package version in image '$Image'. Docker exited with code $LASTEXITCODE.`n$versionOutput"
}

Write-Host -ForegroundColor DarkGray "Checking output for version..."
Write-Host

$version = $null
$line = 1
foreach ($versionOutputLine in $versionOutput) {
    Write-Host -ForegroundColor DarkGray "Checking line $($line): $versionOutputLine"
    $line++

    $trimmedVersionOutputLine = $versionOutputLine.Trim()
    if ($trimmedVersionOutputLine -match "^[0-9][^\s]*$") {
        $version = $trimmedVersionOutputLine
        Write-Host
        Write-Host -ForegroundColor DarkGray "Detected version: $version"
        Write-Host
        break
    }
}

if (-not $version) {
    Write-Error "Failed to detect the ansible package version from image '$Image'."
}

return $version
