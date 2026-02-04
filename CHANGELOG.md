# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
