#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'

$inspectionOutput = @(docker manifest inspect $Image 2>&1)
$inspectionExitCode = $LASTEXITCODE

if ($inspectionExitCode -eq 0) {
    return $true
}

$inspectionMessage = ($inspectionOutput -join [Environment]::NewLine).Trim()
$imageNotFound = $inspectionMessage -match '(?i)manifest unknown|no such manifest|manifest[^\r\n]*not found'

if ($imageNotFound) {
    # The gha-pwsh wrapper propagates $LASTEXITCODE after a step completes. Clear the expected
    # Docker failure in the caller's scope so a successfully handled missing image doesn't fail the step.
    $global:LASTEXITCODE = 0
    return $false
}

throw "Failed to inspect container image '$Image'. Docker exited with code $inspectionExitCode." +
    "$([Environment]::NewLine)$inspectionMessage"
