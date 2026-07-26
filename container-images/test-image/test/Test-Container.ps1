#!/usr/bin/env pwsh

param (
    [string] $Image = 'test-image:local',

    [string] $Platform = '',

    [switch] $GitHubOutput
)

$ErrorActionPreference = 'Stop'

$EXPECTED_VERSION = '0.0'
$VERSION_PATH = '/version.txt'

$dockerArguments = @('run', '--rm')

if ($Platform) {
    $dockerArguments += @('--platform', $Platform)
}

$dockerArguments += @(
    $Image
    'sh'
    '-eu'
    '-c'
    "test `"`$(cat '$VERSION_PATH')`" = '$EXPECTED_VERSION'"
)

Write-Host "Testing image '$Image'$(if ($Platform) { " for platform '$Platform'" })."

& docker @dockerArguments
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    $message = "Test failed for image '$Image' with exit code $exitCode."

    if ($GitHubOutput) {
        Write-Host "::error::$message"
    }

    throw $message
}

Write-Host "Verified test image version '$EXPECTED_VERSION'."
