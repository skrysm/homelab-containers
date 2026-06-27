#!/usr/bin/env pwsh

<#
.SYNOPSIS
Compares installed Alpine packages between two Docker images and writes a Markdown change summary.

.EXAMPLE
./Compare-AlpineImagePackages.ps1 -PublishedImage alpine:3.23 -CandidateImage alpine:3.24

Exit code 0 means no package changes were found.
Exit code 1 means at least one package changed.
Exit code 999 means the comparison failed.

When -PassThru is used, the script returns an object with these properties instead of writing
the Markdown output to the console:
- PackageManifestChanged: Boolean indicating whether package changes were detected.
- MarkdownLines: Markdown lines describing the package comparison.
#>

param (
    [Parameter(Mandatory = $true)]
    [string] $PublishedImage,

    [Parameter(Mandatory = $true)]
    [string] $CandidateImage,

    [switch] $PassThru
)

# Stop on every error
$script:ErrorActionPreference = 'Stop'

try {
    ########################################################################

    function Read-AlpinePackageManifest([string] $Image) {
        # NOTE: Docker pull/progress messages are written to stderr - so they are not
        #   accidentally captured here. Only the output of "sh -c ..." is.
        # NOTE: Sort in PowerShell instead of piping to "sort" inside sh. POSIX sh reports
        #   the exit code of the last pipeline command, so an apk failure could otherwise
        #   be masked by a successful sort and look like an empty package manifest.
        $manifestLines = & docker run --rm "$Image" sh -c 'apk info -vv 2>/dev/null'

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to execute 'apk info -vv' in image '$Image'. Not an Alpine image? Docker exited with code $LASTEXITCODE."
        }

        return @($manifestLines | Sort-Object)
    }

    function ConvertTo-PackageMap([string[]] $ManifestLines) {
        #
        # Example package manifest:
        #
        # alpine-baselayout-3.7.2-r1 - Alpine base dir structure and init scripts
        # alpine-baselayout-data-3.7.2-r1 - Alpine base dir structure and init scripts
        # alpine-keys-2.6-r0 - Public keys for Alpine Linux packages
        # alpine-release-3.24.1-r0 - Alpine release data
        #
        $packages = @{}

        foreach ($line in $ManifestLines) {
            if ($line -notmatch '^(?<Name>.+)-(?<Version>[0-9][^\s]*)\s+-\s+.*$') {
                Write-Error "Package manifest line has unexpected format: $line"
            }

            $packages[$Matches.Name] = $Matches.Version
        }

        return $packages
    }

    $publishedManifestLines = Read-AlpinePackageManifest -Image $PublishedImage
    $candidateManifestLines = Read-AlpinePackageManifest -Image $CandidateImage

    $publishedPackages = ConvertTo-PackageMap -ManifestLines $publishedManifestLines
    $candidatePackages = ConvertTo-PackageMap -ManifestLines $candidateManifestLines

    $packageNames = @($publishedPackages.Keys + $candidatePackages.Keys | Sort-Object -Unique)

    $changeLines = @()

    foreach ($packageName in $packageNames) {
        $publishedPackageExists = $publishedPackages.ContainsKey($packageName)
        $candidatePackageExists = $candidatePackages.ContainsKey($packageName)

        if ($publishedPackageExists -and $candidatePackageExists) {
            $publishedVersion = $publishedPackages[$packageName]
            $candidateVersion = $candidatePackages[$packageName]

            if ($publishedVersion -ne $candidateVersion) {
                $changeLines += "- ``$packageName``: ``$publishedVersion`` → ``$candidateVersion``"
            }
        }
        elseif ($candidatePackageExists) {
            $changeLines += "- ``$packageName``: added ``$($candidatePackages[$packageName])``"
        }
        else {
            $changeLines += "- ``$packageName``: removed ``$($publishedPackages[$packageName])``"
        }
    }

    # NOTE: We can't just compare the manifest lines for equality because they contain descriptions
    #  and we still want "$PackageManifestChanged = $false" if just the description of package has
    #  changed but not the package version.
    $hasChanges = $changeLines.Count -ne 0
    if ($hasChanges) {
        $packageCount = $changeLines.Count
        $packageIntroText = if ($packageCount -eq 1) { "package has" } else { "packages have" }

        $markdownLines = @(
            "**$packageCount $packageIntroText changed:**"
            ''
        ) + $changeLines
    }
    else {
        $markdownLines = @("No package version changes detected.")
    }

    if ($PassThru) {
        return [PSCustomObject] @{
            PackageManifestChanged = $hasChanges
            MarkdownLines          = $markdownLines
        }
    }
    else {
        Write-Output $markdownLines

        if ($hasChanges) {
            # Exit code 1 = changes have been found
            exit 1
        }
        else {
            # Exit code 0 = no changes
            exit 0
        }
    }

    ########################################################################
}
catch {
    if ($PassThru) {
        throw
    }

    function LogError([string] $exception) {
        Write-Host -ForegroundColor Red $exception
    }

    # Type of $_: System.Management.Automation.ErrorRecord

    # NOTE: According to https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/windows-powershell-error-records
    #   we should always use '$_.ErrorDetails.Message' instead of '$_.Exception.Message' for displaying the message.
    #   In fact, there are cases where '$_.ErrorDetails.Message' actually contains more/better information than '$_.Exception.Message'.
    if ($_.ErrorDetails -And $_.ErrorDetails.Message) {
        $unhandledExceptionMessage = $_.ErrorDetails.Message
    }
    elseif ($_.Exception -And $_.Exception.Message) {
        $unhandledExceptionMessage = $_.Exception.Message
    }
    else {
        $unhandledExceptionMessage = 'Could not determine error message from ErrorRecord'
    }

    # IMPORTANT: We compare type names(!) here - not actual types. This is important because - for example -
    #   the type 'Microsoft.PowerShell.Commands.WriteErrorException' is not always available (most likely
    #   when Write-Error has never been called).
    if ($_.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.WriteErrorException') {
        # Print error messages (without stacktrace)
        LogError $unhandledExceptionMessage
    }
    else {
        # Print proper exception message (including stack trace)
        # NOTE: We can't create a catch block for "RuntimeException" as every exception
        #   seems to be interpreted as RuntimeException.
        if ($_.Exception.GetType().FullName -eq 'System.Management.Automation.RuntimeException') {
            LogError "$unhandledExceptionMessage$([Environment]::NewLine)$($_.ScriptStackTrace)"
        }
        else {
            LogError "$($_.Exception.GetType().Name): $unhandledExceptionMessage$([Environment]::NewLine)$($_.ScriptStackTrace)"
        }
    }

    # Exit code 999 = error
    exit 999
}
