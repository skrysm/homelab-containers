#!/usr/bin/env pwsh

#
# Determines the primary software version from the installed Caddy application.
#

param (
    [string] $Image = 'caddy-cloudflare:local'
)

$ErrorActionPreference = 'Stop'

$versionOutput = @(& docker run --rm $Image caddy version 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to run 'caddy version' in image '$Image'. Docker exited with code $LASTEXITCODE.`n$(($versionOutput | Out-String).Trim())"
}

$versionLine = ([string] ($versionOutput | Select-Object -First 1)).Trim()
if ($versionLine -notmatch '^v(?<Version>[0-9]+\.[0-9]+\.[0-9]+)(?:\s|$)') {
    throw "Failed to detect the Caddy version from image '$Image'. Output: $versionLine"
}

$Matches.Version
