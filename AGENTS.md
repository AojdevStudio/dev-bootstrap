# Repository Guidelines

## Project Structure & Module Organization
- `bootstrap.ps1` is the single entrypoint for Windows setup and installs all tools.
- `wsl/setup.sh` handles optional WSL-side setup after WSL2 is enabled.
- `scripts/check-structure.ps1` validates required repo files and CI expectations.
- `.github/workflows/repo-health.yml` runs the structure check on push/PR.
- `README.md` documents the one-liner installer and supported flags.

## Build, Test, and Development Commands
- `pwsh -File ./bootstrap.ps1`  
  Run the Windows bootstrap locally. Use `-SkipWSL` to bypass WSL setup.
- `pwsh -File ./scripts/check-structure.ps1`  
  Validate required files/paths; used by CI.
- `wsl/setup.sh`  
  WSL-side setup executed by `bootstrap.ps1` after `wsl --install`.

## Coding Style & Naming Conventions
- PowerShell scripts use two-space indentation and PascalCase for functions.
- Bash scripts use `set -euo pipefail` and explicit `#!/usr/bin/env bash` shebangs.
- File names are descriptive and kebab/flat (e.g., `check-structure.ps1`).
- Keep comments short and use inline links only for canonical sources.

## Testing Guidelines
- There is no unit test framework; CI runs a structure check.
- Use `./scripts/check-structure.ps1` before submitting changes.
- If you add new required files, update the required list in `scripts/check-structure.ps1`.

## Commit & Pull Request Guidelines
- Commit history is short and uses concise, imperative subjects (e.g., `Mark wsl/setup.sh executable`).
- Use a short, direct subject line; add detail in the body if needed.
- PRs should describe what the bootstrap changes, note any new installers, and mention flags or WSL impact.
- If you modify install sources, update links in `bootstrap.ps1` and `README.md`.

## Security & Configuration Tips
- `bootstrap.ps1` installs tools from official sources; keep URLs canonical.
- Avoid adding credentials or tokens to scripts or docs.
