# Repository Guidelines

## General Guidelines

* Prefer PowerShell scripts over bash scripts, wherever possible.
* Ignore stages Git changes and treat them as non existent. Only inspect unstaged changes. Never change the Git staging area unless told to.

## PowerShell Guidelines

* If a variable is really a constant, use ALL_UPPER_CASE for its name.
* For simple PowerShell functions, prefer inline parameter declarations (for example, `function Get-Value($InputValue) { ... }`) over a `param (...)` block. Use a `param (...)` block when advanced parameter features make it necessary.
* Don't use `[PSCustomObject]` if a regular `@{ ... }` is enough.
* When iterating items, prefer `foreach` over pipelines - unless the code can be expressed in an easy-to-read way in a single line.
* Consider adding a few short comments to generated code. Especially, if the generated code is longer, use comments to explain the various larger code blocks.
* Use simple string interpolation instead of `Join-Path`, e.g. `$basePath/file`.

## GitHub Actions Guidelines

* Prefer "inline" use of GitHub Action variables (i.e. `${{ ... }}`) in scripts - instead of using environment variables for them - unless there is evidence that the contents of the variables require using environment variables.
* In a composite action, prefer to store long scripts in dedicated script files. But keep short scripts (less than 30 lines) inlined in the action itself.
