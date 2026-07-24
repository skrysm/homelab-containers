#!/usr/bin/env pwsh

param (
    [Parameter(Mandatory = $true)]
    [string] $Image
)

$ErrorActionPreference = 'Stop'

# importlib.metadata reads distributions visible to the image's default Python interpreter.
# This avoids depending on pip and works the same way on Alpine, Debian, and Ubuntu.
$PYTHON_SCRIPT = @'
import importlib.metadata
import json
import re

packages = {}

for distribution in importlib.metadata.distributions():
    package_name = distribution.metadata.get("Name")
    if not package_name:
        continue

    # Python package names are case-insensitive and treat "-", "_", and "." as equivalent.
    canonical_name = re.sub(r"[-_.]+", "-", package_name).lower()
    version = distribution.version

    if canonical_name in packages and packages[canonical_name] != version:
        raise RuntimeError(
            f"Multiple versions of Python package {canonical_name!r} are installed: "
            f"{packages[canonical_name]!r} and {version!r}"
        )

    packages[canonical_name] = version

print(json.dumps(packages, sort_keys=True, separators=(",", ":")))
'@

$outputLines = @(& docker run --rm $Image python3 -c $PYTHON_SCRIPT)
if ($LASTEXITCODE -ne 0) {
    throw "Failed to collect the Python package manifest from image '$Image'. Docker exited with code $LASTEXITCODE."
}
if ($outputLines.Count -ne 1 -or -not $outputLines[0]) {
    throw "Python package manifest from image '$Image' did not contain exactly one JSON document."
}

$manifest = ConvertFrom-Json -InputObject $outputLines[0]
$packages = @{}

foreach ($property in $manifest.PSObject.Properties) {
    $packages[$property.Name] = [string] $property.Value
}

return @{
    Label    = 'Python packages'
    Type     = 'python'
    Packages = $packages
}
