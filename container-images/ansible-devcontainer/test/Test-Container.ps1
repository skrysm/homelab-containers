#!/usr/bin/env pwsh

<#
.SYNOPSIS
Runs a minimal smoke test against the Ansible devcontainer image.

.DESCRIPTION
The test starts short-lived containers from the given image and verifies that
the image works as a basic Ansible devcontainer.

It checks these cases:

1. The default user is the non-root vscode user.
2. Expected command line tools are available.
3. Passwordless sudo works for the vscode user.
4. Python can import Ansible-related packages.
5. Ansible can execute a local ping module invocation.

.EXAMPLE
./Test-Container.ps1 -Image ansible-devcontainer:local
#>

param (
    [string] $Image = "ansible-devcontainer:local",

    [string] $Platform = '',

    [switch] $GitHubOutput
)

# Stop on every error
$script:ErrorActionPreference = 'Stop'

try {
    ########################################################################

    function Write-Title([string] $Text) {
        Write-Host -ForegroundColor Cyan $Text
        Write-Host
    }

    function Invoke-ContainerCommand {
        param (
            [Parameter(Mandatory = $true)]
            [string] $Description,

            [Parameter(Mandatory = $true)]
            [string[]] $Command
        )

        Write-Host "Checking: $Description"

        $dockerArguments = @('run', '--rm')

        if ($Platform) {
            $dockerArguments += @('--platform', $Platform)
        }

        $dockerArguments += @($Image) + $Command

        $outputLines = & docker @dockerArguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($outputLines) {
            $outputLines | ForEach-Object { Write-Host "  $_" }
        }

        if ($exitCode -ne 0) {
            $text = ($outputLines | Out-String).Trim()
            throw "docker $($dockerArguments -join ' ') failed with exit code $exitCode.`n$text"
        }

        Write-Host "Verified: $Description"
        Write-Host
    }

    function Assert-ContainerStarts {
        Invoke-ContainerCommand `
            -Description "container starts" `
            -Command @('true')
    }

    function Assert-DefaultUser {
        Invoke-ContainerCommand `
            -Description "default user is vscode" `
            -Command @(
                'sh',
                '-lc',
                'test "$(id -un)" = vscode && test "$(id -gn)" = vscode && test "$HOME" = /home/vscode'
            )
    }

    function Assert-DevcontainerFiles {
        Invoke-ContainerCommand `
            -Description "devcontainer user files exist" `
            -Command @(
                'sh',
                '-lc',
                'test -d "$HOME/.oh-my-zsh" && test -f "$HOME/.zshrc" && test -d "$HOME/.ssh"'
            )
    }

    function Assert-EditorEnvironment {
        Invoke-ContainerCommand `
            -Description "EDITOR points to nano" `
            -Command @(
                'sh',
                '-lc',
                'test "$EDITOR" = nano'
            )
    }

    function Assert-ToolsAreAvailable {
        $tools = @(
            'ansible',
            'ansible-playbook',
            'ansible-vault',
            'ansible-lint',
            'python3',
            'pip3',
            'git',
            'ssh',
            'sshpass',
            'sudo',
            'zsh',
            'nano',
            'ping'
        )

        $toolList = $tools -join ' '

        Invoke-ContainerCommand `
            -Description "expected tools are available" `
            -Command @(
                'sh',
                '-lc',
                "for tool in $toolList; do command -v ""`$tool"" >/dev/null || exit 1; done"
            )
    }

    function Assert-VersionCommandsWork {
        Invoke-ContainerCommand `
            -Description "Ansible version commands work" `
            -Command @(
                'sh',
                '-lc',
                'ansible --version && ansible-playbook --version && ansible-vault --version && ansible-lint --version'
            )
    }

    function Assert-PasswordlessSudoWorks {
        Invoke-ContainerCommand `
            -Description "passwordless sudo works" `
            -Command @('sudo', '-n', 'true')
    }

    function Assert-PythonPackagesAreAvailable {
        $pythonScript = @'
import importlib.metadata

for package_name in ("ansible", "ansible-lint", "passlib"):
    print(f"{package_name}=={importlib.metadata.version(package_name)}")

import ansible
import passlib.hash
'@

        Invoke-ContainerCommand `
            -Description "Ansible Python packages are available" `
            -Command @('python3', '-c', $pythonScript)
    }

    function Assert-LocalAnsiblePingWorks {
        Invoke-ContainerCommand `
            -Description "local Ansible ping works" `
            -Command @(
                'ansible',
                'localhost',
                '--inventory',
                'localhost,',
                '--connection',
                'local',
                '--module-name',
                'ansible.builtin.ping'
            )
    }

    if ($Platform) {
        Write-Title "Testing Ansible devcontainer image '$Image' for platform '$Platform'."
    }
    else {
        Write-Title "Testing Ansible devcontainer image '$Image'."
    }

    Assert-ContainerStarts
    Assert-DefaultUser
    Assert-DevcontainerFiles
    Assert-EditorEnvironment
    Assert-ToolsAreAvailable
    Assert-VersionCommandsWork
    Assert-PasswordlessSudoWorks
    Assert-PythonPackagesAreAvailable
    Assert-LocalAnsiblePingWorks

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
