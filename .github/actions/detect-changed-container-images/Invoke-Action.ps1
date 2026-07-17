#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BaseSha,

    [Parameter(Mandatory = $true)]
    [string] $HeadSha
)

$ErrorActionPreference = 'Stop'

$changedFiles = @(
    git diff --name-only --no-renames "${BaseSha}...${HeadSha}" --
)

if ($LASTEXITCODE -ne 0) {
    throw "Failed to determine changed files. Git exited with code $LASTEXITCODE."
}

function Test-PathChanged($Patterns) {
    foreach ($file in $changedFiles) {
        foreach ($pattern in $Patterns) {
            if ($file -like $pattern) {
                return $true
            }
        }
    }

    return $false
}

$sharedPublishingChanged = Test-PathChanged @(
    '.github/actions/*'
    '.github/workflows/_publish-container-image.yml'
    '.github/workflows/build-gate.yml'
)

$imageNames = @()

foreach ($directory in (Get-ChildItem -Path . -Directory)) {
    $configurationPath = Join-Path $directory.FullName 'container-image-config.yml'

    if (Test-Path $configurationPath -PathType Leaf) {
        $imageNames += $directory.Name
    }
}

# Make the order of execution predictable/consistent across runs
[Array]::Sort($imageNames)

$containerImages = @()
$changedImages = @()

foreach ($imageName in $imageNames) {
    $validationRequired = $sharedPublishingChanged -or (Test-PathChanged @(
        ".github/workflows/publish-$imageName.yml"
        "$imageName/*"
    ))

    $containerImages += @{
        Name               = $imageName
        ValidationRequired = $validationRequired
    }

    if ($validationRequired) {
        $changedImages += $imageName
    }
}

$changedImagesJson = ConvertTo-Json -InputObject $changedImages -Compress
"changed_images=$changedImagesJson" >> $env:GITHUB_OUTPUT

$summaryLines = @(
    '## Container image change detection'
    ''
    '| Image | Validation required |'
    '| ----- | ------------------- |'
)

foreach ($containerImage in $containerImages) {
    $summaryLines += "| $($containerImage.Name) | $($containerImage.ValidationRequired) |"
}

$summaryLines >> $env:GITHUB_STEP_SUMMARY

# Required so that this step doesn't fail if $LASTEXITCODE is still non-zero.
exit 0
