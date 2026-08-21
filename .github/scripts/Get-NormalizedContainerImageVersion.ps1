#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BuildContext,

    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'
$VERSION_PATTERN = '^[0-9]+\.[0-9]+(?:\.[0-9]+)?$'

$versionScript = "$BuildContext/Get-ContainerImageVersion.ps1"
if (-not (Test-Path -LiteralPath $versionScript -PathType Leaf)) {
    throw "Version script '$versionScript' was not found."
}

$versionOutput = @(& $versionScript -Image $Image)
if ($versionOutput.Count -ne 1) {
    throw "Expected exactly one container image version from '$Image', but received $($versionOutput.Count)."
}

$detectedVersion = [string] $versionOutput[0]
if ($detectedVersion -notmatch $VERSION_PATTERN) {
    throw "Invalid container image version '$detectedVersion' from '$Image'. Expected 'x.y' or 'x.y.z', with numeric components."
}

# Renovate and Dependabot treat an x.y Docker tag as a rolling minor-version tag and preserve
# its precision - meaning they won't update a "1.2" tag to "1.2.1". However, they will update
# a "1.2.0" tag to "1.2.1". That's why we normalize "x.y" to "x.y.0".
$normalizedVersion = if ($detectedVersion -match '^[0-9]+\.[0-9]+$') {
    "$detectedVersion.0"
}
else {
    $detectedVersion
}

return [version] $normalizedVersion
