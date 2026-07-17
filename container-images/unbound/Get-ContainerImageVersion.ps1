#!/usr/bin/env pwsh

#
# Determines the container image version from the installed Unbound application.
#

param (
    [string] $Image = "homelab-unbound:local"
)

# Stop on every error
$script:ErrorActionPreference = 'Stop'

try {
    ########################################################################

    $versionOutput = docker run --rm $Image unbound -V
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to run 'unbound -V' in image '$Image'. Docker exited with code $LASTEXITCODE.`n$versionOutput"
    }

    Write-Host -ForegroundColor DarkGray "Checking output for version..."
    Write-Host

    $version = $null
    $line = 1
    foreach ($versionOutputLine in $versionOutput) {
        Write-Host -ForegroundColor DarkGray "Checking line $($line): $versionOutputLine"
        $line++
        if ($versionOutputLine -match "^Version\s+([0-9][^\s]*)") {
            $version = $Matches[1]
            Write-Host
            Write-Host -ForegroundColor DarkGray "Detected version: $version"
            Write-Host
            break
        }
    }

    if (-not $version) {
        Write-Error "Failed to detect Unbound version from image '$Image'."
    }

    $version

    ########################################################################
}
catch {
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

    exit 1
}
