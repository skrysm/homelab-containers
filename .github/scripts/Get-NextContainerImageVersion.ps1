#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $PrimarySoftwareVersion,

    [string] $PublishedContainerImageVersion = ''
)

$ErrorActionPreference = 'Stop'

function ConvertTo-PrimarySoftwareVersion([string] $Value, [string] $Description) {
    $errorMessage = "Invalid $Description '$Value'. Expected 'x.y.z', with numeric components."

    try {
        $parsedVersion = [Version]::new($Value)
    }
    catch {
        throw $errorMessage
    }

    if ($parsedVersion.Build -lt 0 -or $parsedVersion.Revision -ge 0) {
        # Missing version components
        # Version.Build and Version.Revision represent the third and fourth components, respectively.
        throw $errorMessage
    }

    return $parsedVersion
}

function ConvertTo-ContainerImageVersion([string] $Value) {
    $errorMessage = "Invalid published container image version '$Value'. Expected 'x.y.z' or 'x.y.z.d', with numeric components."

    try {
        $parsedVersion = [Version]::new($Value)
    }
    catch {
        throw $errorMessage
    }

    if ($parsedVersion.Build -lt 0) {
        # Missing version component
        # Three components are allowed for legacy images; new image versions always have four.
        throw $errorMessage
    }

    # Normalize a legacy x.y.z image to its implicit revision zero.
    if ($parsedVersion.Revision -lt 0) {
        return [Version]::new(
            $parsedVersion.Major,
            $parsedVersion.Minor,
            $parsedVersion.Build,
            0
        )
    }

    return $parsedVersion
}

$primarySoftwareVersionValue = ConvertTo-PrimarySoftwareVersion `
    -Value $PrimarySoftwareVersion `
    -Description 'primary software version'

if (-not $PublishedContainerImageVersion) {
    # The first published image starts at revision zero.
    return [Version]::new(
        $primarySoftwareVersionValue.Major,
        $primarySoftwareVersionValue.Minor,
        $primarySoftwareVersionValue.Build,
        0
    )
}

$publishedContainerImageVersionValue = ConvertTo-ContainerImageVersion $PublishedContainerImageVersion

# Extract the published primary software version from the container version.
$publishedPrimarySoftwareVersionValue = [Version]::new(
    $publishedContainerImageVersionValue.Major,
    $publishedContainerImageVersionValue.Minor,
    $publishedContainerImageVersionValue.Build
)

if ($primarySoftwareVersionValue -lt $publishedPrimarySoftwareVersionValue) {
    throw "Primary software version '$primarySoftwareVersionValue' is older than the published version '$publishedPrimarySoftwareVersionValue'."
}

if ($primarySoftwareVersionValue -gt $publishedPrimarySoftwareVersionValue) {
    # Newer primary software version. Reset fourth component to zero.
    return [Version]::new(
        $primarySoftwareVersionValue.Major,
        $primarySoftwareVersionValue.Minor,
        $primarySoftwareVersionValue.Build,
        0
    )
}

$publishedRevision = $publishedContainerImageVersionValue.Revision

if ($publishedRevision -eq [int]::MaxValue) {
    # Just to be safe we never go down.
    throw "Published container image revision '$publishedRevision' cannot be incremented any further."
}

return [Version]::new(
    $primarySoftwareVersionValue.Major,
    $primarySoftwareVersionValue.Minor,
    $primarySoftwareVersionValue.Build,
    $publishedRevision + 1
)
