#!/usr/bin/env pwsh

#
# This script generates a Markdown summary of all the package changes between
# a (old) published version and a (new) candidate version. The script returns
# one Markdown line per changed package. If no packages have changed, an empty
# list will be returned.
#
param (
    [Parameter(Mandatory = $true)]
    [hashtable] $PublishedPackages,

    [Parameter(Mandatory = $true)]
    [hashtable] $CandidatePackages
)

$packageNames = @($PublishedPackages.Keys) + @($CandidatePackages.Keys)
$packageNames = $packageNames | Sort-Object -Unique

$changeLines = @()

# Compare by package name so added, removed, and updated packages can be described separately.
foreach ($packageName in $packageNames) {
    $publishedPackageExists = $PublishedPackages.ContainsKey($packageName)
    $candidatePackageExists = $CandidatePackages.ContainsKey($packageName)

    if ($publishedPackageExists -and $candidatePackageExists) {
        # Still exists
        $publishedVersion = $PublishedPackages[$packageName]
        $candidateVersion = $CandidatePackages[$packageName]

        if ($publishedVersion -ne $candidateVersion) {
            # Version has changed
            $changeLines += "- ``$packageName``: ``$publishedVersion`` → ``$candidateVersion``"
        }
    }
    elseif ($candidatePackageExists) {
        # Was added in candidate
        $changeLines += "- ``$packageName``: added ``$($CandidatePackages[$packageName])``"
    }
    else {
        # Was removed in candidate
        $changeLines += "- ``$packageName``: removed ``$($PublishedPackages[$packageName])``"
    }
}

return $changeLines
