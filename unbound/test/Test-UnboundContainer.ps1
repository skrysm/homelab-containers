#!/usr/bin/env pwsh

<#
.SYNOPSIS
Runs a minimal end-to-end test against the Unbound container image.

.DESCRIPTION
The test starts the container with Docker Compose and verifies DNS lookups
through the running Unbound service.

It checks two cases:

1. A real-world DNS name resolves through Unbound.
2. A custom local A record from the mounted test config resolves correctly.

.EXAMPLE
./unbound/test/Test-UnboundContainer.ps1 -Image homelab-unbound:local
#>

param (
    [string] $Image = "homelab-unbound:local",

    [string] $Platform = '',

    [string] $RealWorldName = "example.com",

    [int] $StartupTimeoutSeconds = 30,

    [switch] $GitHubOutput
)


# Stop on every error
$script:ErrorActionPreference = 'Stop'

try {
    ########################################################################

    $PROJECT_NAME = "unbound-test-$([Guid]::NewGuid().ToString('N'))"
    $CUSTOM_NAME = 'healthcheck.homelab.test'
    $CUSTOM_ADDRESS = '1.2.3.4'

    function Write-Title([string] $Text) {
        Write-Host -ForegroundColor Cyan $Text
        Write-Host
    }

    function Invoke-DockerCompose {
        param (
            [Parameter(ValueFromRemainingArguments = $true)]
            [string[]] $Arguments
        )

        $composeFile = Join-Path $PSScriptRoot 'compose.yml'
        $composeArguments = @(
            'compose',
            '--project-name',
            $PROJECT_NAME,
            '--file',
            $composeFile
        ) + $Arguments

        & docker @composeArguments
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            throw "docker $($composeArguments -join ' ') failed with exit code $exitCode."
        }
    }

    function Invoke-DnsLookup([string] $Name) {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            # NOTE: We must use SilentlyContinue here or PowerShell will insert
            #   an error into the output (because on Windows, the text "Non-authoritative answer:"
            #   is apparently written to stderr instead of stdout).
            $ErrorActionPreference = 'SilentlyContinue'

            $outputLines = & nslookup $Name '127.0.0.1' 2>&1

            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($exitCode -ne 0) {
            $text = ($outputLines | Out-String).Trim()
            throw "nslookup $Name 127.0.0.1 failed with exit code $exitCode.`n$text"
        }

        $addresses = Get-ResolvedAddressesFromNsLookupOutput $outputLines

        if (-not $addresses) {
            $text = ($outputLines | Out-String).Trim()
            throw "nslookup $Name 127.0.0.1 did not return any IP addresses.`n$text"
        }

        return @($addresses)
    }

    function Get-UnboundContainerId {
        $containerId = Invoke-DockerCompose ps --quiet unbound

        if (-not $containerId) {
            Write-Error "Could not determine Unbound container ID."
        }

        return $containerId
    }

    function Get-ContainerHealthStatus([string] $ContainerId) {
        $healthStatus = docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' $ContainerId
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            $text = ($healthStatus | Out-String).Trim()
            throw "docker inspect failed for container '$ContainerId' with exit code $exitCode.`n$text"
        }

        return ($healthStatus | Select-Object -First 1).Trim()
    }

    function Get-ResolvedAddressesFromNsLookupOutput([string[]] $OutputLines) {
        #
        # Output on Windows:
        #
        # Server:  unifi.internal
        # Address:  192.168.20.1
        #
        # Non-authoritative answer:
        # Name:    example.com
        # Addresses:  2606:4700:10::ac42:93f3
        #           2606:4700:10::6814:179a
        #           172.66.147.243
        #           104.20.23.154
        #
        #
        # Output on Linux:
        #
        # Server:         10.255.255.254
        # Address:        10.255.255.254#53
        #
        # Non-authoritative answer:
        # Name:   example.com
        # Address: 104.20.23.154
        # Name:   example.com
        # Address: 172.66.147.243
        # Name:   example.com
        # Address: 2606:4700:10::ac42:93f3
        # Name:   example.com
        # Address: 2606:4700:10::6814:179a
        #

        # Skip the first two lines as they contain information about the DNS server, not resolved DNS records.
        # NOTE: We don't look for "Non-authoritative answer:" because this text may not be present on non-English systems.
        $addresses = foreach ($line in ($OutputLines | Select-Object -Skip 2)) {
            # Split line at whitespace.
            foreach ($token in ($line -split '\s+')) {
                $address = $null

                if ([System.Net.IPAddress]::TryParse($token, [ref] $address)) {
                    $address
                }
            }
        }

        $addresses | Select-Object -Unique
    }

    function Assert-ContainerBecomesHealthy([int] $TimeoutSeconds) {
        $containerId = Get-UnboundContainerId
        $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
        $lastHealthStatus = $null

        do {
            $lastHealthStatus = Get-ContainerHealthStatus -ContainerId $containerId

            if ($lastHealthStatus -eq 'healthy') {
                Write-Host "Verified container health status: healthy."
                return
            }

            Write-Host "Container health status: $lastHealthStatus"

            Start-Sleep -Seconds 3
        } while ([DateTimeOffset]::UtcNow -lt $deadline)

        Write-Error "Unbound container did not become healthy within $TimeoutSeconds seconds. Last health status: $lastHealthStatus"
    }

    function Assert-NsLookupIsAvailable {
        if (-not (Get-Command nslookup -ErrorAction SilentlyContinue)) {
            Write-Error "The 'nslookup' command is required to run this test."
        }
    }

    function Assert-ResolvedAddress([System.Net.IPAddress[]] $Addresses, [string] $ExpectedAddress, [string] $Name) {
        $expected = [System.Net.IPAddress]::Parse($ExpectedAddress)

        if ($expected -notin $Addresses) {
            Write-Error "Expected '$Name' to resolve to '$ExpectedAddress'. Resolved addresses: $($Addresses -join ', ')"
        }
    }

    function Assert-ResolvesToPublicAddress([System.Net.IPAddress[]] $Addresses, [string] $Name) {
        # Check if at least one address is not a loopback address.
        $publicAddresses = $Addresses | Where-Object { -not [System.Net.IPAddress]::IsLoopback($_) }

        if (-not $publicAddresses) {
            Write-Error "Expected '$Name' to resolve to at least one public address. Resolved addresses: $($Addresses -join ', ')"
        }
    }

    $failed = $true

    try {
        $env:UNBOUND_TEST_IMAGE = $Image

        if ($Platform) {
            $env:UNBOUND_TEST_PLATFORM = $Platform
        }

        Assert-NsLookupIsAvailable

        if ($Platform) {
            Write-Title "Starting Unbound test stack '$PROJECT_NAME' from image '$Image' for platform '$Platform'."
        }
        else {
            Write-Title "Starting Unbound test stack '$PROJECT_NAME' from image '$Image'."
        }

        Invoke-DockerCompose up --detach

        Write-Host
        Write-Title "Wait for container to become healthy"

        Assert-ContainerBecomesHealthy -TimeoutSeconds $StartupTimeoutSeconds

        Write-Host
        Write-Title "Running verification tests"


        $customAddresses = Invoke-DnsLookup -Name $CUSTOM_NAME
        Assert-ResolvedAddress -Addresses $customAddresses -ExpectedAddress $CUSTOM_ADDRESS -Name $CUSTOM_NAME
        Write-Host "Verified custom DNS record '$CUSTOM_NAME' -> '$CUSTOM_ADDRESS'."

        $realWorldAddresses = Invoke-DnsLookup -Name $RealWorldName
        Assert-ResolvesToPublicAddress -Addresses $realWorldAddresses -Name $RealWorldName
        Write-Host "Verified real-world DNS lookup for '$RealWorldName' -> '$($realWorldAddresses[0])'."

        $failed = $false
    }
    finally {
        if ($failed) {
            Write-Host
            Write-Title "Unbound container logs"

            try {
                Invoke-DockerCompose logs --no-color unbound
            }
            catch {
                Write-Host $_
            }
        }

        Write-Host
        Write-Title "Shutting down test stack '$PROJECT_NAME'"
        try {
            Invoke-DockerCompose down --volumes --remove-orphans
        }
        catch {
            Write-Host $_
        }
    }

########################################################################
}
catch {
    function LogError([string] $exception) {
        if ($GitHubOutput) {
            Write-Host -ForegroundColor Red "::error::$exception"
        }
        else {
            Write-Host -ForegroundColor Red $exception
        }
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
