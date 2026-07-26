#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image,

    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $ExpectedDigest,

    [Parameter(Mandatory = $true)]
    [string] $ExpectedPlatforms
)

$ErrorActionPreference = 'Stop'

$MAX_ATTEMPTS = 5
$RETRY_DELAY_SECONDS = 10

#
# Functions
#

# Resolves an image reference and return its manifest after verifying that it points to the expected digest.
function Get-VerifiedImageManifest($ImageReference, $ExpectedImageDigest) {
    $lastResolvedDigest = ''

    # Retry to account for brief registry propagation delays.
    for ($attempt = 1; $attempt -le $MAX_ATTEMPTS; $attempt++) {
        $manifestJson = & docker buildx imagetools inspect $ImageReference --format '{{json .Manifest}}'

        if ($LASTEXITCODE -eq 0) {
            $manifest = $manifestJson | ConvertFrom-Json
            $lastResolvedDigest = ([string] $manifest.digest).Trim()

            if ($lastResolvedDigest -eq $ExpectedImageDigest) {
                Write-Host "Verified '$ImageReference' -> $lastResolvedDigest"
                return $manifest
            }

            Write-Warning "Image '$ImageReference' resolved to '$lastResolvedDigest', expected '$ExpectedImageDigest'."
        }
        else {
            Write-Warning "Could not resolve image '$ImageReference'."
        }

        if ($attempt -lt $MAX_ATTEMPTS) {
            Write-Host "Retrying in $RETRY_DELAY_SECONDS seconds..."
            Start-Sleep -Seconds $RETRY_DELAY_SECONDS
        }
    }

    throw "Image '$ImageReference' did not resolve to expected digest '$ExpectedImageDigest'. " +
        "Last resolved digest: '$lastResolvedDigest'."
}

# Verifies that an image manifest contains every expected runtime platform.
function Assert-ExpectedImagePlatforms($ImageReference, $Manifest, $ExpectedDockerPlatforms) {
    $manifestDescriptors = @($Manifest.manifests)

    # Gather all platforms from the image manifest.
    $actualPlatforms = @()
    foreach ($descriptor in $manifestDescriptors) {
        $os = ([string] $descriptor.platform.os).Trim()
        $architecture = ([string] $descriptor.platform.architecture).Trim()
        $variant = ([string] $descriptor.platform.variant).Trim()

        # Attestations appear in the image index as unknown/unknown and aren't runtime platforms.
        if ((-not $os) -or (-not $architecture) -or ($os -eq 'unknown') -or ($architecture -eq 'unknown')) {
            continue
        }

        $platform = "$os/$architecture"
        if ($variant) {
            $platform += "/$variant"
        }

        if ($platform -notin $actualPlatforms) {
            $actualPlatforms += $platform
        }
    }

    $missingPlatforms = @()
    foreach ($expectedPlatform in $ExpectedDockerPlatforms) {
        $expectedParts = @($expectedPlatform -split '/')
        $platformFound = $false

        foreach ($descriptor in $manifestDescriptors) {
            $platform = $descriptor.platform
            $platformFound = ($expectedParts[0] -eq $platform.os) `
                        -and ($expectedParts[1] -eq $platform.architecture) `
                        -and (($expectedParts.Count -lt 3) -or ($expectedParts[2] -eq $platform.variant))

            if ($platformFound) {
                break
            }
        }

        if (-not $platformFound) {
            $missingPlatforms += $expectedPlatform
        }
    }

    if ($missingPlatforms.Count -gt 0) {
        throw "Image '$ImageReference' is missing expected platforms: $($missingPlatforms -join ', '). " +
            "Published platforms: $($actualPlatforms -join ', ')."
    }

    Write-Host "Verified platforms for '$ImageReference': $($actualPlatforms -join ', ')"
}

#
# Main Script
#

if ($ExpectedDigest -notmatch '^sha256:[0-9a-f]{64}$') {
    throw "Invalid expected image digest '$ExpectedDigest'."
}

$EXPECTED_DOCKER_PLATFORMS = @()
foreach ($platform in ($ExpectedPlatforms -split ',').Trim()) {
    if ($platform) {
        $EXPECTED_DOCKER_PLATFORMS += $platform
    }
}

if ($EXPECTED_DOCKER_PLATFORMS.Count -eq 0) {
    throw 'At least one expected Docker platform must be specified.'
}

$LATEST_IMAGE = "${Image}:latest"
$VERSIONED_IMAGE = "${Image}:$Version"

$LATEST_MANIFEST = Get-VerifiedImageManifest `
    -ImageReference $LATEST_IMAGE `
    -ExpectedImageDigest $ExpectedDigest

$VERSIONED_MANIFEST = Get-VerifiedImageManifest `
    -ImageReference $VERSIONED_IMAGE `
    -ExpectedImageDigest $ExpectedDigest

Assert-ExpectedImagePlatforms `
    -ImageReference $LATEST_IMAGE `
    -Manifest $LATEST_MANIFEST `
    -ExpectedDockerPlatforms $EXPECTED_DOCKER_PLATFORMS

Assert-ExpectedImagePlatforms `
    -ImageReference $VERSIONED_IMAGE `
    -Manifest $VERSIONED_MANIFEST `
    -ExpectedDockerPlatforms $EXPECTED_DOCKER_PLATFORMS
