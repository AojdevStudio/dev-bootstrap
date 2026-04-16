# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]


## [1.3.0] - 2026-04-16

### Added

- GitHub CLI (`gh`) installed via winget (`GitHub.cli`) in the Base tools section. Lets you authenticate with GitHub and interact with repos from the terminal without leaving the installer.

### Fixed

- Re-runs no longer duplicate work that's already done. `fnm install --lts` previously emitted `Installing Node vX.Y.Z` followed immediately by `warning: Version already installed`; it's now skipped when fnm reports any installed Node. `uv python install 3.12` is now gated on `uv python find 3.12` exit code — skipped when 3.12 is already managed. `npm install -g @openai/codex` is now gated on `npm ls -g @openai/codex` — skipped when already installed.
- Claude Code migration from npm (pre-v1.2.0) is now automatic. On re-run, if `@anthropic-ai/claude-code` is still present via npm, it is silently uninstalled before the native winget binary resolves, so there's only one `claude` on PATH.

## [1.2.0] - 2026-04-16

### Changed

- Windows: Claude Code now installs as a **native binary via winget** (`Anthropic.ClaudeCode`) instead of via `npm install -g @anthropic-ai/claude-code`. Anthropic's documentation marks npm installation as deprecated and recommends the native installer. WinGet was chosen over the `irm https://claude.ai/install.ps1 | iex` native installer because it preserves the proxy-compatibility promise of commit `d24ad9b` (Zscaler and similar proxies block `irm | iex`). This eliminates an entire class of fnm/npm PATH fragility bugs that drove v1.1.0 through v1.1.2 patch releases.
- README + SECURITY.md install-source tables updated to reflect the new Claude Code install path.

### Notes

- **Manual updates for Claude Code.** The `irm | iex` native installer auto-updates Claude Code in the background; the winget install does not. Run `winget upgrade Anthropic.ClaudeCode` periodically to stay current. Users who prefer auto-updates and are not behind a proxy that blocks piped remote execution can install via `irm https://claude.ai/install.ps1 | iex` instead.
- **Codex CLI still installs via npm.** OpenAI does not publish a winget package for Codex CLI.

## [1.1.2] - 2026-04-16

### Fixed

- Windows: WSL section no longer crashes with `Cannot bind argument to parameter 'Path' because it is an empty string` when the installer is invoked via `irm | iex`. `$PSCommandPath` is empty in that case, so the wsl/setup.sh second-phase step now guards on script-on-disk and prints clone-and-run instructions otherwise.
- Windows: reboot-detection regex on `wsl --install` output now matches the common `Changes will not be effective until the system is rebooted` phrasing (previous regex only caught `reboot is required` / `reboot your computer` variants and missed past-tense `rebooted`).

## [1.1.1] - 2026-04-16

### Fixed

- Windows: removed `fnm use --lts` call that several recent fnm builds from winget reject with `unexpected argument '--lts' found`. `fnm install --lts` already activates the version in the current shell, so the follow-up call was both redundant and broken.
- Windows: Claude Code and Codex install sections now re-activate fnm before calling `npm install -g`, then check `$LASTEXITCODE` and throw a clear error when npm fails. Prevents silent failures where the script continued and halted later with a confusing "Missing command: claude" message.

## [1.1.0] - 2026-04-16

### Added

- macOS bootstrap script (`macos/bootstrap.sh`) with Homebrew-driven install of the full toolchain, plus structure checks for the repo
- macOS extras: `lazygit` and `yazi` installed via Homebrew
- WSL provisioning now installs `chromium-browser` via apt for Playwright/headless workflows
- ChatGPT custom-instructions builder prompt under `prompts/`
- `SECURITY.md` policy and an `[Unreleased]` section in the changelog

### Fixed

- Windows: hardened `bootstrap.ps1` against real-world friction on managed/school/enterprise machines — PATH now merges (not overwrites) session and registry scopes so fnm's Node stays resolvable; winget install checks now require both exit code and package-id match for idempotency; the `dev-bootstrap: fnm` profile snippet upgrades in place on re-runs; fnm is invoked with `--shell powershell` and eager-activates the default Node so `npm` works in the home dir; the concrete LTS version is resolved rather than the fragile `lts-latest` alias; uv's managed Python dir is prepended to PATH so the Microsoft Store `python.exe` alias in `WindowsApps` stops shadowing the real interpreter; `wsl --install` now detects "reboot required" output and bails out cleanly with next-step guidance
- Replaced `irm | iex` installers with winget/npm to bypass corporate proxies (e.g., Zscaler) that block piped remote execution
- Corrected GitHub org URLs throughout README (`Jarvis-AojDevStuio` → `AojdevStudio`) and Buy Me a Coffee username format

### Changed

- README now prefixes Windows install one-liners with `Set-ExecutionPolicy -Scope Process` so the installer works on managed machines where the default `Restricted` policy blocks `iex`, and documents the `uv run python` pattern (and why it's needed on Windows)

## [v1.0.0] - 2026-02-04

### Added
- Initial Windows developer bootstrap script (`bootstrap.ps1`) with automated tool installation
- WSL setup script (`wsl/setup.sh`) for Linux environment configuration
- Support for installing Git, Node.js (via fnm), Python, VS Code, Docker Desktop, and Windows Terminal
- Post-install README notes and guidance for new developers
- Sudo preflight check for WSL setup to prevent permission issues
- AGENTS.md with repository guidelines for AI-assisted development
- GitHub FUNDING.yml for project sponsorship
- Comprehensive README with project story, architecture diagram, installation walkthrough, and FAQ
- Project assets including hero banner, architecture diagram, and podcast clip

### Fixed
- fnm error guidance improved for clearer troubleshooting
- Installer finish messaging improved for better user experience
- WSL setup script marked as executable for proper permissions

### Changed
- README overhauled from minimal stub into comprehensive project documentation
- YouTube thumbnail replaced with GitHub-hosted video embed for cleaner presentation


## Links
[Unreleased]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/AojdevStudio/dev-bootstrap/compare/v1.0.0...v1.1.0
[v1.0.0]: https://github.com/AojdevStudio/dev-bootstrap/releases/tag/v1.0.0
