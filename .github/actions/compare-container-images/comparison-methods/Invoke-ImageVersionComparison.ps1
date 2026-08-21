#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BuildContext,

    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage
)

# Shared workflow scripts live under .github, outside this action's directory.
$githubDirectory = (Resolve-Path "$PSScriptRoot/../../..").Path
$versionHelperScript = "$githubDirectory/scripts/Get-NormalizedContainerImageVersion.ps1"

if (-not (Test-Path -LiteralPath $versionHelperScript -PathType Leaf)) {
    throw "Version helper script '$versionHelperScript' was not found."
}

$candidateVersion = & $versionHelperScript -BuildContext $BuildContext -Image $CandidateImage
$publishedVersion = & $versionHelperScript -BuildContext $BuildContext -Image $PublishedImage

$detailLines = @(
    "**Candidate version:** ``$candidateVersion``"
    ''
    "**Published version:** ``$publishedVersion``"
)

return @{
    Changed     = $candidateVersion -ne $publishedVersion
    DetailLines = $detailLines
}
