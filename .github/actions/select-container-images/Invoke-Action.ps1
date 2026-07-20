#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $BaseSha,

    [Parameter(Mandatory = $true)]
    [string] $HeadSha,

    [Parameter(Mandatory = $true)]
    [ValidateSet('changed', 'all')]
    [string] $SelectionMode
)

$ErrorActionPreference = 'Stop'

# NOTE: Must not(!) start with "./" because "git diff" returns the paths without this prefix.
$IMAGES_BASE_PATH = 'container-images'

$imageNames = @()

foreach ($directory in (Get-ChildItem -Path $IMAGES_BASE_PATH -Directory)) {
    $configurationPath = Join-Path $directory.FullName 'container-image-config.yml'

    if (Test-Path $configurationPath -PathType Leaf) {
        $imageNames += $directory.Name
    }
}

# Make the order of execution predictable/consistent across runs
[Array]::Sort($imageNames)

if ($SelectionMode -eq 'all') {
    $selectedImages = @($imageNames)
}
else {
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

    $sharedFilesChanged = Test-PathChanged @(
        '.github/actions/*'
        '.github/workflows/publish-container-image.yml'
        # Include the calling workflows so that changes to them trigger builds for all(!) images.
        # Without these entries, all image builds would be skipped.
        # NOTE: This script can be called from a PR (which necessitates "pr.yml") as well as a
        #   push to the main branch (which necessitates "ci.yml").
        '.github/workflows/ci.yml'
        '.github/workflows/pr.yml'
    )

    $selectedImages = @()

    foreach ($imageName in $imageNames) {
        $imageSelected = $sharedFilesChanged -or (Test-PathChanged "$IMAGES_BASE_PATH/$imageName/*")

        Write-Host "Container image '$imageName': selected = $imageSelected"

        if ($imageSelected) {
            $selectedImages += $imageName
        }
    }
}

$selectedImagesJson = ConvertTo-Json -InputObject $selectedImages -Compress
"selected_images=$selectedImagesJson" >> $env:GITHUB_OUTPUT

# Only add a summary to this action if no container images were selected.
# Selected images each add their own summary to the workflow run.
if ($selectedImages.Count -eq 0) {
    @(
        '## Container image validation'
        ''
        'No container images require validation.'
    ) >> $env:GITHUB_STEP_SUMMARY
}

# Required so that this step doesn't fail if $LASTEXITCODE is still non-zero.
exit 0
