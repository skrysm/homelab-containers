# Repository Guidelines

## General Guidelines

* Prefer PowerShell scripts over bash scripts, wherever possible.
* Ignore stages Git changes and treat them as non existent. Only inspect unstaged changes. Never change the Git staging area unless told to.

## PowerShell Guidelines

* For simple PowerShell functions, prefer inline parameter declarations (for example, `function Get-Value($InputValue) { ... }`) over a `param (...)` block. Use a `param (...)` block when advanced parameter features make it necessary.

## GitHub Actions Guidelines

* Prefer "inline" use of GitHub Action variables (i.e. `${{ ... }}`) in scripts - instead of using environment variables for them - unless there is evidence that the contents of the variables require using environment variables.
* In a composite action, prefer to store long scripts in dedicated script files. But keep short scripts (less than 30 lines) inlined in the action itself.
