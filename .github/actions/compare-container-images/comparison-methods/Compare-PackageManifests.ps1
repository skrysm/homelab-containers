#!/usr/bin/env pwsh

<#
.SYNOPSIS
Compares selected package manifests between two Docker images and writes a Markdown change summary.

.EXAMPLE
./Compare-PackageManifests.ps1 `
    -PublishedImage ghcr.io/example/tool:latest `
    -CandidateImage tool:candidate `
    -ManifestTypes 'os, python'

Exit code 0 means no package changes were found.
Exit code 1 means at least one package changed.
Exit code 999 means the comparison failed.

When -PassThru is used, the script returns a hashtable with these properties instead of writing
the Markdown output to the console:
- PackageManifestChanged: Boolean indicating whether package changes were detected.
- MarkdownLines: Markdown lines describing the package comparisons.
#>

param (
    [Parameter(Mandatory = $true)]
    [string] $PublishedImage,

    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $ManifestTypes,

    [switch] $PassThru
)

$script:ErrorActionPreference = 'Stop'

try {
    $manifestRoot = "$PSScriptRoot/package-manifests"

    #
    # Normalize and validate manifest types.
    #
    $normalizedManifestTypes = @()

    foreach ($manifestTypeValue in $ManifestTypes.Split(',')) {
        $manifestType = $manifestTypeValue.Trim().ToLowerInvariant()

        if (-not $manifestType) {
            continue
        }

        if ($manifestType -notmatch '^[a-z0-9][a-z0-9-]*$') {
            throw "Invalid package manifest type '$manifestTypeValue'."
        }

        if ($manifestType -notin $normalizedManifestTypes) {
            if (-not (Test-Path "$manifestRoot/$manifestType" -PathType Container)) {
                $supportedManifestTypes = @((Get-ChildItem -LiteralPath $manifestRoot -Directory).Name | Sort-Object)
                $supportedManifestTypesText = $supportedManifestTypes -join "', '"
                throw "Unsupported package manifest type '$manifestTypeValue'. Supported types are '$supportedManifestTypesText'."
            }

            $normalizedManifestTypes += $manifestType
        }
    }

    if ($normalizedManifestTypes.Count -eq 0) {
        throw 'At least one package manifest type must be specified.'
    }

    #
    # Calculate changes for every selected package manifest type
    #
    $hasChanges = $false
    $markdownLines = @()

    foreach ($manifestType in $normalizedManifestTypes) {
        # Each manifest script returns the same Label/Type/Packages structure.
        $manifestScript = "$manifestRoot/$manifestType/Get-PackageManifest.ps1"

        $publishedManifest = & $manifestScript -Image $PublishedImage
        $candidateManifest = & $manifestScript -Image $CandidateImage

        $markdownLines += "### $($candidateManifest.Label)"
        $markdownLines += ''

        # Package names are not comparable across different OS package ecosystems.
        if ($publishedManifest.Type -ne $candidateManifest.Type) {
            $hasChanges = $true
            $markdownLines += "Package manifest type changed from ``$($publishedManifest.Type)`` to ``$($candidateManifest.Type)``."
            $markdownLines += ''
            continue
        }

        $changeLines = @(
            & "$PSScriptRoot/package-manifests/New-PackageManifestMarkdownDiff.ps1" `
                -PublishedPackages $publishedManifest.Packages `
                -CandidatePackages $candidateManifest.Packages
        )

        if ($changeLines.Count -eq 0) {
            $markdownLines += 'No package version changes detected.'
        }
        else {
            $hasChanges = $true
            $packageCount = $changeLines.Count
            $packageIntroText = if ($packageCount -eq 1) { 'package has' } else { 'packages have' }

            $markdownLines += "**$packageCount $packageIntroText changed:**"
            $markdownLines += ''
            $markdownLines += $changeLines
        }

        $markdownLines += ''
    }

    if ($PassThru) {
        return @{
            PackageManifestChanged = $hasChanges
            MarkdownLines          = $markdownLines
        }
    }

    Write-Output $markdownLines
    if ($hasChanges) {
        exit 1
    }
    exit 0
}
catch {
    if ($PassThru) {
        throw
    }

    Write-Host -ForegroundColor Red $_
    exit 999
}
