#!/usr/bin/env pwsh

# Runs smoke tests against the Caddy container image.
# Verifies Cloudflare DNS configuration and the HTTP server.

param (
    [string] $Image = 'caddy-cloudflare:local',

    [string] $Platform = '',

    [int] $StartupTimeoutSeconds = 15,

    [switch] $GitHubOutput
)

$ErrorActionPreference = 'Stop'

$CONTAINER_NAME = "caddy-test-$([Guid]::NewGuid().ToString('N'))"

# Returns Docker run arguments containing the optional test platform and specified command.
function Get-DockerRunArguments([string[]] $Command) {
    $arguments = @('run', '--rm')

    if ($Platform) {
        $arguments += @('--platform', $Platform)
    }

    return $arguments + @($Image) + $Command
}

# Runs the specified command in a short-lived container and throws when it fails.
function Invoke-ContainerCommand([string] $Description, [string[]] $Command) {
    Write-Host "Checking: $Description"

    $dockerArguments = Get-DockerRunArguments -Command $Command
    $outputLines = @(& docker @dockerArguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($outputLines) {
        foreach ($line in $outputLines) {
            Write-Host "  $line"
        }
    }

    if ($exitCode -ne 0) {
        $text = ($outputLines | Out-String).Trim()
        throw "docker $($dockerArguments -join ' ') failed with exit code $exitCode.`n$text"
    }

    Write-Host "Verified: $Description"
    Write-Host
}

# Verifies that Caddy accepts the Cloudflare DNS provider in a Caddyfile.
function Assert-CloudflareDnsProviderCanBeConfigured {
    $command = @'
printf '%s\n' \
    'example.test {' \
    '	tls {' \
    '		dns cloudflare {env.CF_API_TOKEN}' \
    '	}' \
    '	respond "ok"' \
    '}' \
    | caddy adapt --adapter caddyfile --config - >/dev/null
'@

    Invoke-ContainerCommand `
        -Description 'Cloudflare DNS provider can be configured in a Caddyfile' `
        -Command @('sh', '-eu', '-c', $command)
}

# Starts Caddy and verifies that it serves the specified response body over HTTP.
function Assert-CaddyServesHttp([string] $ExpectedResponse) {
    $dockerArguments = @('run', '--detach', '--name', $CONTAINER_NAME)
    if ($Platform) {
        $dockerArguments += @('--platform', $Platform)
    }
    $dockerArguments += @(
        $Image
        'caddy'
        'respond'
        '--listen'
        ':8080'
        '--body'
        $ExpectedResponse
    )

    $startOutput = @(& docker @dockerArguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start Caddy test container '$CONTAINER_NAME'.`n$(($startOutput | Out-String).Trim())"
    }

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($StartupTimeoutSeconds)
    do {
        $response = & docker exec $CONTAINER_NAME wget -qO- http://127.0.0.1:8080 2>$null
        if ($LASTEXITCODE -eq 0 -and $response -eq $ExpectedResponse) {
            Write-Host "Verified: Caddy served the specified HTTP response body '$ExpectedResponse'."
            Write-Host
            return
        }

        Start-Sleep -Milliseconds 500
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    $logs = (& docker logs $CONTAINER_NAME 2>&1 | Out-String).Trim()
    throw "Caddy did not serve the specified HTTP response body '$ExpectedResponse' within $StartupTimeoutSeconds seconds.`n$logs"
}

$failed = $true

try {
    Write-Host "Testing image '$Image'$(if ($Platform) { " for platform '$Platform'" })."
    Write-Host

    Assert-CaddyServesHttp -ExpectedResponse 'caddy-cloudflare-test'
    Assert-CloudflareDnsProviderCanBeConfigured

    $failed = $false
}
catch {
    if ($GitHubOutput) {
        Write-Host "::error::$($_.Exception.Message)"
    }

    throw
}
finally {
    & docker rm --force $CONTAINER_NAME 2>$null | Out-Null

    if ($failed) {
        Write-Host "Caddy image tests failed."
    }
}
