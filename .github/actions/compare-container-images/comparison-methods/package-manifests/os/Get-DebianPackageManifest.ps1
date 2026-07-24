#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'

# Include the dpkg status (Status-Abbrev) so entries with only configuration files left can be ignored.
$MANIFEST_COMMAND = @'
dpkg-query --show --showformat='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n'
'@

$manifestLines = @(& docker run --rm $Image sh -c $MANIFEST_COMMAND)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to collect the Debian package manifest from image '$Image'. Docker exited with code $LASTEXITCODE."
}
if ($manifestLines.Count -eq 0) {
    throw "The Debian package manifest from image '$Image' is empty."
}

$packages = @{}

foreach ($line in @($manifestLines | Sort-Object)) {
    if ($line -notmatch '^(?<Status>.{3})\t(?<Name>[^\t]+)\t(?<Version>[^\t]+)$') {
        throw "Debian package manifest line has unexpected format: $line"
    }

    # "ii " means that the package is selected for installation and fully installed.
    if ($Matches.Status -eq 'ii ') {
        $packages[$Matches.Name] = $Matches.Version
    }
}

return @{
    Label    = 'Debian packages'
    Type     = 'debian'
    Packages = $packages
}
