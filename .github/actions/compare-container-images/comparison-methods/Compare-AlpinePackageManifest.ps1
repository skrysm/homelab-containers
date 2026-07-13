#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage
)

$comparison = ./scripts/Compare-AlpinePackageManifests.ps1 `
    -PublishedImage $PublishedImage `
    -CandidateImage $CandidateImage `
    -PassThru

$changed = $comparison.PackageManifestChanged

if ($changed) {
    $outcomeMessage = "At least one package version changed between the candidate image and '$PublishedImage'."
    $detailLines = @($comparison.MarkdownLines)
}
else {
    $outcomeMessage = "No package version changes between the candidate image and '$PublishedImage'."
    $detailLines = @()
}

return @{
    Changed        = $changed
    OutcomeMessage = $outcomeMessage
    DetailLines    = $detailLines
}
