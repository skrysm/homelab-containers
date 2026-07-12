# Repository Guidelines

## General Guidelines

* Prefer PowerShell scripts over bash scripts, wherever possible.
* Ignore stages Git changes and treat them as non existent. Only inspect unstaged changes. Never change the Git staging area unless told to.

## GitHub Actions Guidelines

* Prefer "inline" use of GitHub Action variables (i.e. `${{ ... }}`) in scripts - instead of using environment variables for them - unless there is evidence that the contents of the variables require using environment variables.
