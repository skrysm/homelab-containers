[CmdletBinding()]
param (
    [string] $Image = "unbound-version-probe:local",
    [string] $GitHubOutputName
)

$ErrorActionPreference = "Stop"

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"

try {
    $versionOutput = docker run --rm $Image unbound -V 2>&1
} finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($LASTEXITCODE -ne 0) {
    throw "Failed to run 'unbound -V' in image '$Image'. Docker exited with code $LASTEXITCODE.`n$versionOutput"
}

$version = $versionOutput |
    ForEach-Object {
        if ($_ -match "^Version\s+([0-9][^\s]*)") {
            $Matches[1]
        }
    } |
    Select-Object -First 1

if (-not $version) {
    throw "Failed to detect Unbound version from image '$Image'.`n$versionOutput"
}

if ($GitHubOutputName) {
    if (-not $env:GITHUB_OUTPUT) {
        throw "GitHub output name '$GitHubOutputName' was specified, but GITHUB_OUTPUT is not set."
    }

    Add-Content -Path $env:GITHUB_OUTPUT -Value "$GitHubOutputName=$version" -Encoding utf8
}

$version
