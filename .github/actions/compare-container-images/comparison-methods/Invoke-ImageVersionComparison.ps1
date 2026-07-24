#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BuildContext,

    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage
)

$versionScript = "$BuildContext/Get-ContainerImageVersion.ps1"

if (-not (Test-Path -LiteralPath $versionScript -PathType Leaf)) {
    throw "Version script '$versionScript' was not found."
}

function Get-ImageVersion([string] $Image) {
    $versionOutput = @(& $versionScript -Image $Image)

    if ($versionOutput.Count -ne 1 -or -not $versionOutput[0]) {
        throw "Version script '$versionScript' did not return exactly one version for image '$Image'."
    }

    return [string] $versionOutput[0]
}

$candidateVersion = Get-ImageVersion -Image $CandidateImage
$publishedVersion = Get-ImageVersion -Image $PublishedImage

$detailLines = @(
    "**Candidate version:** ``$candidateVersion``"
    ''
    "**Published version:** ``$publishedVersion``"
)

if ($candidateVersion -eq $publishedVersion) {
    $changed = $false
    $outcomeMessage = "The image version is unchanged compared to '$PublishedImage'."
}
else {
    $changed = $true
    $outcomeMessage = "The image version changed from '$publishedVersion' to '$candidateVersion'."
}

return @{
    Changed        = $changed
    OutcomeMessage = $outcomeMessage
    DetailLines    = $detailLines
}
