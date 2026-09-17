#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image,

    [string] $GitHubToken = $env:GITHUB_TOKEN
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

# GHCR can respond with "denied" for a package that has never been published. Check the
# package itself before deciding whether that response means "missing" or an access error.
if ($inspectionMessage -match '(?i)\bdenied\b' -and
    $Image -match '^ghcr\.io/(?<Owner>[^/]+)/(?<Package>[^:]+):[^:]+$') {
    if (-not $GitHubToken) {
        throw "GHCR denied access to '$Image', and no GitHub token was supplied to check whether its package exists."
    }

    $owner = $Matches.Owner
    $packageName = $Matches.Package
    $headers = @{
        Authorization = "Bearer $GitHubToken"
        Accept = 'application/vnd.github+json'
    }

    $ownerResponse = Invoke-WebRequest -Uri "https://api.github.com/users/$owner" -Headers $headers -SkipHttpErrorCheck
    if ($ownerResponse.StatusCode -ne 200) {
        throw "Failed to identify GitHub package owner '$owner'. GitHub API returned HTTP $($ownerResponse.StatusCode)."
    }

    $ownerType = (ConvertFrom-Json -InputObject $ownerResponse.Content).type
    $ownerPath = switch ($ownerType) {
        'User' { 'users' }
        'Organization' { 'orgs' }
        default { throw "Unsupported GitHub package owner type '$ownerType' for '$owner'." }
    }

    $encodedPackageName = [Uri]::EscapeDataString($packageName)
    $packageUrl = "https://api.github.com/$ownerPath/$owner/packages/container/$encodedPackageName"
    $packageResponse = Invoke-WebRequest -Uri $packageUrl -Headers $headers -SkipHttpErrorCheck

    if ($packageResponse.StatusCode -eq 404) {
        # Clear the handled Docker failure for the gha-pwsh wrapper.
        $global:LASTEXITCODE = 0
        return $false
    }

    throw "Failed to check GitHub package '$packageName'. GitHub API returned HTTP $($packageResponse.StatusCode)."
}

throw "Failed to inspect container image '$Image'. Docker exited with code $inspectionExitCode." +
    "$([Environment]::NewLine)$inspectionMessage"
