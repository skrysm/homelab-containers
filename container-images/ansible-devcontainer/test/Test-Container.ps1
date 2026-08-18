#!/usr/bin/env pwsh

<#
.SYNOPSIS
Runs a minimal smoke test against the Ansible devcontainer image.

.DESCRIPTION
The test starts short-lived containers from the given image and verifies that
the image works as a basic Ansible devcontainer.

It checks these cases:

1. The default user is the non-root vscode user.
2. The persistent state directories are configured for Codex and zsh.
3. zsh stores its history in the persistent state directory.
4. Expected command line tools are available.
5. Passwordless sudo works for the vscode user.
6. Python can import Ansible- and Mitogen-related packages.
7. Ansible can execute a local ping module invocation.
8. Ansible can load and execute Mitogen's strategy and action plugins.

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
            'test -d "$HOME/.oh-my-zsh" && test -f "$HOME/.zshrc" && test "$(readlink "$HOME/.ssh")" = "/workspace/ssh"'
        )
}

function Assert-PersistentState {
    Invoke-ContainerCommand `
        -Description "/persist has the expected permissions and owner" `
        -Command @(
            'sh',
            '-lc',
            'test -d /persist && test "$(stat -c %a /persist)" = 700 && test "$(stat -c %U:%G /persist)" = vscode:vscode'
        )

    Invoke-ContainerCommand `
        -Description "Codex uses its persistent directory" `
        -Command @(
            'sh',
            '-lc',
            'test "$CODEX_HOME" = /persist/codex && test -d "$CODEX_HOME" && test -w "$CODEX_HOME"'
        )

    Invoke-ContainerCommand `
        -Description "zsh persistent directory is writable" `
        -Command @(
            'sh',
            '-lc',
            'test -d /persist/zsh && test -w /persist/zsh'
        )

    Invoke-ContainerCommand `
        -Description "zsh history uses its persistent directory" `
        -Command @(
            'zsh',
            '-ic',
            'test "$HISTFILE" = /persist/zsh/history'
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
    # NOTE: This list exists mainly to prevent accidental removal of necessary/helpful tools.
    $tools = @(
        'ansible',
        'ansible-playbook',
        'ansible-vault',
        'ansible-lint',
        'python3',
        'git',
        'ssh',
        'sshpass',
        'sudo',
        'nano',
        'ping',
        'dig',
        'nslookup',
        'curl',
        'wget',
        'unzip',
        'rsync',
        'jq',
        'yq'
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

for package_name in ("ansible", "ansible-lint", "mitogen", "passlib", "typer"):
    print(f"{package_name}=={importlib.metadata.version(package_name)}")

import ansible
import ansible_mitogen
import mitogen
import passlib.hash
import typer
'@

    Invoke-ContainerCommand `
        -Description "Ansible and Mitogen Python packages are available" `
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

function Assert-MitogenIntegrationWorks {
    Invoke-ContainerCommand `
        -Description "Mitogen integrates with Ansible" `
        -Command @(
            'sh',
            '-lc',
            'ANSIBLE_STRATEGY=mitogen_linear ansible localhost --inventory localhost, --connection local --module-name mitogen_get_stack'
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
Assert-PersistentState
Assert-EditorEnvironment
Assert-ToolsAreAvailable
Assert-VersionCommandsWork
Assert-PasswordlessSudoWorks
Assert-PythonPackagesAreAvailable
Assert-LocalAnsiblePingWorks
Assert-MitogenIntegrationWorks
