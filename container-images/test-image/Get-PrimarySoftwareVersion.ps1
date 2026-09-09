#!/usr/bin/env pwsh

param (
    [string] $Image = 'test-image:local'
)

$ErrorActionPreference = 'Stop'

$VERSION_PATH = '/version.txt'
$versionOutput = @(& docker run --rm $Image cat $VERSION_PATH)

if ($LASTEXITCODE -ne 0) {
    throw "Failed to read the version from image '$Image'. Docker exited with code $LASTEXITCODE."
}

if ($versionOutput.Count -ne 1) {
    throw "Expected exactly one version line in image '$Image', but received $($versionOutput.Count)."
}

([string] $versionOutput[0]).Trim()
