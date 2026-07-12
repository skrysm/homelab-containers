#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage
)

docker manifest inspect "$PublishedImage" *> $null
$publishedImageExists = $LASTEXITCODE -eq 0

$summaryLines = @(
    "## Package manifest comparison"
    ""
    "**Comparison image:** ``$PublishedImage``"
    ""
)

if (-not $publishedImageExists) {
    $packageManifestChanged = $true
    $comparisonReason = "No previous published image was found at '$PublishedImage'."
    $packageComparisonMarkdownLines = @()
}
else {
    $packageComparison = ./scripts/Compare-AlpineImagePackages.ps1 `
        -PublishedImage $PublishedImage `
        -CandidateImage $CandidateImage `
        -PassThru

    $packageManifestChanged = $packageComparison.PackageManifestChanged
    $packageComparisonMarkdownLines = @($packageComparison.MarkdownLines)

    if (-not $packageManifestChanged) {
        $comparisonReason = "No package version changes between the candidate image and '$PublishedImage'."
        $packageComparisonMarkdownLines = @()
    }
    else {
        $comparisonReason = "At least one package version changed between the candidate image and '$PublishedImage'."
    }
}

Write-Host "Package manifest comparison result: $comparisonReason"

"package_manifest_changed=$($packageManifestChanged.ToString().ToLowerInvariant())" >> $env:GITHUB_OUTPUT

if ($packageComparisonMarkdownLines.Count -gt 0) {
    $summaryLines += $packageComparisonMarkdownLines
}
elseif ($comparisonReason) {
    $summaryLines += $comparisonReason
}

$summaryLines >> $env:GITHUB_STEP_SUMMARY

# Required so that this step doesn't fail if $LASTEXITCODE is still non-zero.
exit 0
