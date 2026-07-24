#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'

# Do sorting and parsing in PowerShell (instead of inside the container) so an apk failure cannot be hidden by a shell pipe.
$manifestLines = @(& docker run --rm $Image sh -c 'apk info -vv 2>/dev/null')
if ($LASTEXITCODE -ne 0) {
    throw "Failed to collect the Alpine package manifest from image '$Image'. Docker exited with code $LASTEXITCODE."
}
if ($manifestLines.Count -eq 0) {
    throw "The Alpine package manifest from image '$Image' is empty."
}

$packages = @{}

foreach ($line in @($manifestLines | Sort-Object)) {
    # Example: alpine-baselayout-3.7.2-r1 - Alpine base dir structure and init scripts
    if ($line -notmatch '^(?<Name>.+)-(?<Version>[0-9][^\s]*)\s+-\s+.*$') {
        throw "Alpine package manifest line has unexpected format: $line"
    }

    $packages[$Matches.Name] = $Matches.Version
}

return @{
    Label    = 'Alpine packages'
    Type     = 'alpine'
    Packages = $packages
}
