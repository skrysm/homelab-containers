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

$ansibleDevcontainerChanged = $sharedPublishingChanged -or (Test-PathChanged @(
    '.github/workflows/publish-ansible-devcontainer.yml'
    'ansible-devcontainer/*'
))

$unboundChanged = $sharedPublishingChanged -or (Test-PathChanged @(
    '.github/workflows/publish-unbound.yml'
    'unbound/*'
))

$changedImages = @()

if ($ansibleDevcontainerChanged) {
    $changedImages += 'ansible-devcontainer'
}

if ($unboundChanged) {
    $changedImages += 'unbound'
}

$changedImagesJson = ConvertTo-Json -InputObject $changedImages -Compress
"changed_images=$changedImagesJson" >> $env:GITHUB_OUTPUT

@(
    '## Container image change detection'
    ''
    '| Image | Validation required |'
    '| --- | --- |'
    "| Ansible devcontainer | $ansibleDevcontainerChanged |"
    "| Unbound | $unboundChanged |"
) >> $env:GITHUB_STEP_SUMMARY
