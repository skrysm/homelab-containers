#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BuildContext,

    [Parameter(Mandatory = $true)]
    [string] $ComparisonMethod,

    [string] $PackageManifests = '',

    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BuildContext -PathType Container)) {
    throw "Build context '$BuildContext' was not found."
}

$comparisonTitle = switch ($ComparisonMethod) {
    'package-manifest' { 'Package manifest' }
    'version' { 'Container image version' }
    default { throw "Unsupported comparison method '$ComparisonMethod'. Supported methods are 'package-manifest' and 'version'." }
}

docker manifest inspect $PublishedImage *> $null
$publishedImageExists = $LASTEXITCODE -eq 0

if (-not $publishedImageExists) {
    $comparisonResult = @{
        Changed        = $true
        OutcomeMessage = "Published image '$PublishedImage' doesn't exist."
        DetailLines    = @()
    }
}
else {
    $comparisonResult = switch ($ComparisonMethod) {
        'package-manifest' {
            # Default package manifest types to "os" if none are specified - as this should be the
            # sensible default for most containers.
            if (-not $PackageManifests) {
                $PackageManifests = 'os'
            }

            $comparison = & "$PSScriptRoot/comparison-methods/Compare-PackageManifests.ps1" `
                -CandidateImage $CandidateImage `
                -PublishedImage $PublishedImage `
                -ManifestTypes $PackageManifests `
                -PassThru

            $changed = $comparison.PackageManifestChanged
            $outcomeMessage = if ($changed) {
                "At least one package version changed between the candidate image and '$PublishedImage'."
            }
            else {
                "No package version changes between the candidate image and '$PublishedImage'."
            }

            @{
                Changed        = $changed
                OutcomeMessage = $outcomeMessage
                DetailLines    = @($comparison.MarkdownLines)
            }
        }
        'version' {
            & "$PSScriptRoot/comparison-methods/Invoke-ImageVersionComparison.ps1" `
                -BuildContext $BuildContext `
                -CandidateImage $CandidateImage `
                -PublishedImage $PublishedImage
        }
    }
}

if ($null -eq $comparisonResult -or $null -eq $comparisonResult.Changed) {
    throw "Comparison method '$ComparisonMethod' did not return a valid result."
}

$comparisonStatus = if (-not $publishedImageExists) {
    '🆕 No published image'
}
elseif ($comparisonResult.Changed) {
    '🔄 Changes detected'
}
else {
    '✅ No changes detected'
}

$summaryLines = @(
    "## $comparisonTitle comparison"
    ''
    "**Result:** $comparisonStatus"
    ''
    "**Published comparison image:** ``$PublishedImage``"
    ''
)

$detailLines = @($comparisonResult.DetailLines)
if ($detailLines.Count -gt 0) {
    $summaryLines += $detailLines
    $summaryLines += ''
}

$summaryLines += $comparisonResult.OutcomeMessage

Write-Host "Container image comparison result: $($comparisonResult.OutcomeMessage)"

"changes_detected=$($comparisonResult.Changed.ToString().ToLowerInvariant())" >> $env:GITHUB_OUTPUT
$summaryLines >> $env:GITHUB_STEP_SUMMARY

# Required so that this step doesn't fail if $LASTEXITCODE is still non-zero.
exit 0
