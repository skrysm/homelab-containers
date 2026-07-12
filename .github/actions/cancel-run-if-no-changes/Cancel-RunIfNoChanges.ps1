#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $ChangesDetected,

    [Parameter(Mandatory = $true)]
    [string] $PublishedImage,

    [Parameter(Mandatory = $true)]
    [string] $RunId,

    [Parameter(Mandatory = $true)]
    [string] $Repository
)

$ErrorActionPreference = 'Stop'

function Write-PublishDecision([bool] $ShouldPublish, [string] $Reason) {
    $decision = if ($ShouldPublish) { '✅ Publish image' } else { '⏭️ Do not publish image' }

    Write-Host "${decision}: $Reason"

    @(
        '## Publish decision'
        ''
        "**Decision:** $decision"
        ''
        "**Reason:** $Reason"
    ) >> $env:GITHUB_STEP_SUMMARY
}

$shouldPublish = switch ($ChangesDetected) {
    'true' { $true }
    'false' { $false }
    default { throw "Invalid changes-detected value '$ChangesDetected'. Expected 'true' or 'false'." }
}

if ($shouldPublish) {
    docker manifest inspect $PublishedImage *> $null
    $publishedImageExists = $LASTEXITCODE -eq 0

    if ($publishedImageExists) {
        $reason = "Changes were detected compared to '$PublishedImage'."
    }
    else {
        $reason = "No previous published image was found at '$PublishedImage'."
    }
}
else {
    $reason = "No changes were detected compared to '$PublishedImage'."
}

Write-PublishDecision `
    -ShouldPublish $shouldPublish `
    -Reason $reason

if (-not $shouldPublish) {
    gh run cancel $RunId --repo $Repository
    Start-Sleep -Seconds 30
    Write-Error 'Cancellation request did not stop this run in time.'
    exit 1
}

# Required so that this step doesn't fail if $LASTEXITCODE is still non-zero.
exit 0
