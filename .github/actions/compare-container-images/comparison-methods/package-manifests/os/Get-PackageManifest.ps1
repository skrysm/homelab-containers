#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'

# Detect the OS package manager by capability rather than relying on a particular /etc/os-release value.
$OS_DETECTION_COMMAND = @'
if command -v apk >/dev/null 2>&1; then
    echo 'alpine'
elif command -v dpkg-query >/dev/null 2>&1; then
    echo 'debian'
else
    echo 'No supported OS package manager found.' >&2
    exit 127
fi
'@

$outputLines = @(& docker run --rm $Image sh -c $OS_DETECTION_COMMAND)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to detect the OS package manager in image '$Image'. Docker exited with code $LASTEXITCODE."
}
if ($outputLines.Count -ne 1) {
    throw "Expected one OS package manager name from image '$Image', but received $($outputLines.Count)."
}

switch ($outputLines[0]) {
    'alpine' { return & "$PSScriptRoot/Get-AlpinePackageManifest.ps1" -Image $Image }
    'debian' { return & "$PSScriptRoot/Get-DebianPackageManifest.ps1" -Image $Image }
    default { throw "Image '$Image' returned an unknown OS package manager: $($outputLines[0])" }
}
