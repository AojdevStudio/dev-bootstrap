# Dev Bootstrap

Dev Bootstrap is a one-command Windows-first developer environment installer for fresh machines. Its language distinguishes default full-stack setup from intentionally skipped WSL-dependent setup.

## Language

**Bootstrap run**:
A single execution of the installer that prepares a machine with the repo's supported developer toolchain.
_Avoid_: setup script run, installer pass

**WSL-enabled run**:
A bootstrap run without `-SkipWSL` that may require administrator elevation, reboot handling, and WSL-dependent tools such as Docker Desktop.
_Avoid_: default run when the WSL/admin implications matter

**WSL-skipped run**:
A bootstrap run with `-SkipWSL` that avoids WSL-dependent setup and prints manual follow-up guidance instead.
_Avoid_: lightweight run, non-admin run

**Auto-updating native Claude Code install**:
The Anthropic Windows native installer path that installs Claude Code outside npm and receives background updates.
_Avoid_: npm Claude Code, WinGet Claude Code when automatic updates are required

## Relationships

- A **Bootstrap run** is either a **WSL-enabled run** or a **WSL-skipped run**.
- A **WSL-enabled run** installs Docker Desktop after WSL is available or instructs the user to rerun after reboot.
- A **WSL-skipped run** does not install Docker Desktop, but still gives the user Docker setup directions.
- An **Auto-updating native Claude Code install** is preferred when freshness matters more than strict WinGet-only package sourcing.

## Example dialogue

> **Dev:** "Should Docker install when I pass `-SkipWSL`?"
> **Domain expert:** "No. That is a **WSL-skipped run**. Skip Docker, then print clear manual Docker setup steps at the end."

## Flagged ambiguities

- "Native Claude Code" was ambiguous between the WinGet package and Anthropic's native installer. Resolved: when automatic updates are required, use the **Auto-updating native Claude Code install**.
