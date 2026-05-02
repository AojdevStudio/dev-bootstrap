<#
Windows-first bootstrap.

Canonical sources:
- WSL: https://learn.microsoft.com/en-us/windows/wsl/install
- uv: https://github.com/microsoft/winget-pkgs (astral-sh.uv)
- Bun: https://github.com/microsoft/winget-pkgs (Oven-sh.Bun)
- Claude Code: https://code.claude.com/docs/en/setup
- Codex CLI: https://developers.openai.com/codex/cli
- Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/
- Git for Windows: https://git-scm.com/download/win
- winget: https://learn.microsoft.com/en-us/windows/package-manager/winget/
#>

[CmdletBinding()]
param(
  [switch]$SkipWSL
)

$BootstrapUrl = "https://raw.githubusercontent.com/AojdevStudio/dev-bootstrap/main/bootstrap.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Section([string]$t) {
  Write-Host "`n== $t ==" -ForegroundColor Cyan
}

function IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p  = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function EnsureAdminForWSL {
  if ($SkipWSL) { return }
  if (IsAdmin) { return }

  Write-Host "Re-launching as Administrator (needed for WSL and Docker Desktop)..." -ForegroundColor Yellow
  if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", "`"$PSCommandPath`""
    ) + $MyInvocation.UnboundArguments
  } else {
    # When invoked via `irm | iex`, there is no script file to pass to -File.
    # Re-run the canonical one-liner elevated instead.
    $command = "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force; irm '$BootstrapUrl' | iex"
    $args = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-Command", $command
    )
  }

  Start-Process powershell.exe -Verb RunAs -ArgumentList $args | Out-Null
  exit 0
}

function Need([string]$name, [string]$hint = $null) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    if ($hint) {
      throw "Missing command: $name. $hint"
    }
    throw "Missing command: $name"
  }
}

function EnsureWinget {
  if (Get-Command winget -ErrorAction SilentlyContinue) { return }
  throw "winget not found. Install 'App Installer' from Microsoft Store, then rerun. https://learn.microsoft.com/en-us/windows/package-manager/winget/"
}

function RefreshPath {
  # Merge (not replace): preserve session additions (e.g., fnm's Node dir)
  # while picking up anything a recent installer wrote to Machine/User scopes.
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $registryPath = @($machinePath, $userPath) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd(';') } | Where-Object { $_ } | ForEach-Object { $_ -split ';' }
  $sessionPath = @($env:Path -split ';' | Where-Object { $_ })

  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $merged = New-Object 'System.Collections.Generic.List[string]'
  foreach ($p in @($sessionPath + $registryPath)) {
    if ($p -and $seen.Add($p)) { $merged.Add($p) | Out-Null }
  }
  $env:Path = ($merged -join ';')
}

function PrependPathIfExists([string]$pathToAdd) {
  if (-not (Test-Path $pathToAdd)) { return }
  if (($env:Path -split ';') -contains $pathToAdd) { return }
  $env:Path = "$pathToAdd;$env:Path"
}

function FindUvPython([string]$version) {
  # `uv python find` writes an expected "not found" message to stderr and
  # exits non-zero when the interpreter is absent. Under
  # `$ErrorActionPreference = "Stop"`, PowerShell can promote that stderr
  # record into a terminating NativeCommandError. Probe it with stderr muted.
  $found = ''
  $exitCode = 1
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $found = (& uv python find $version 2>$null | Out-String).Trim()
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  return [pscustomobject]@{
    ExitCode = $exitCode
    Path = $found
  }
}

function WinGetInstall([string]$id) {
  # Idempotency: winget list can exit 0 with "No installed package found" text
  # on some versions, so we can't trust exit code alone. Require BOTH the
  # success exit code AND a literal match of the package id in the output.
  $listed = ''
  try { $listed = (winget list --id $id -e --source winget 2>&1 | Out-String) } catch { $listed = '' }
  if ($LASTEXITCODE -eq 0 -and $listed -match [regex]::Escape($id)) {
    Write-Host "Already installed: $id" -ForegroundColor DarkGray
    return
  }
  Write-Host "Installing: $id"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -eq 3010) {
    Write-Host "Installed: $id (reboot required to finish setup)" -ForegroundColor Yellow
    return
  }
  if ($LASTEXITCODE -ne 0) {
    throw "winget install $id failed with exit code $LASTEXITCODE. Fix the error above and re-run."
  }
}

function EnsureProfileSnippet([string]$marker, [string]$snippet) {
  $profileDir = Split-Path -Parent $PROFILE
  if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir | Out-Null }
  if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE | Out-Null }

  $content = Get-Content $PROFILE -Raw
  if ($null -eq $content) { $content = '' }

  # Block delimiters are the marker line and the terminating dashes written
  # inside the snippet. We look up the marker and REPLACE any existing block
  # so that re-runs upgrade older profile snippets in place.
  $blockPattern = '(?s)# ---- ' + [regex]::Escape($marker) + ' ----.*?# ----------------------------'
  $normalizedSnippet = $snippet.Trim()

  if ($content -match $blockPattern) {
    if ($Matches[0] -ne $normalizedSnippet) {
      $updated = $content.Replace($Matches[0], $normalizedSnippet)
      Set-Content -Path $PROFILE -Value $updated -NoNewline
      Write-Host "Upgraded profile block: $marker" -ForegroundColor DarkGray
    }
  } else {
    Add-Content -Path $PROFILE -Value "`n$normalizedSnippet`n"
  }
}

# -------------------- MAIN --------------------
Section "Preflight"
EnsureWinget
EnsureAdminForWSL

Section "Base tools"
# Git for Windows: https://git-scm.com/download/win
WinGetInstall "Git.Git"
# cURL: https://learn.microsoft.com/en-us/windows/package-manager/winget/
WinGetInstall "cURL.cURL"
# GitHub CLI: https://cli.github.com/
WinGetInstall "GitHub.cli"
# Windows Terminal: modern terminal with tabs, Unicode, GPU rendering.
# Default on Windows 11; this install is mainly for Windows 10.
WinGetInstall "Microsoft.WindowsTerminal"

Section "Node via fnm + npm"
WinGetInstall "Schniz.fnm"
RefreshPath

if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
  $fnmPath = Join-Path $env:LOCALAPPDATA "fnm\fnm.exe"
  if (Test-Path $fnmPath) {
    $env:Path = "$env:Path;$((Split-Path -Parent $fnmPath))"
  }
}

Need "fnm" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
EnsureProfileSnippet "dev-bootstrap: fnm" @'
# ---- dev-bootstrap: fnm ----
if (Get-Command fnm -ErrorAction SilentlyContinue) {
  fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
  # Eager-activate the default Node so `npm`/globals work in home dir
  # without needing a `cd` into a project with a .node-version file.
  fnm use default 2>$null | Out-Null
}
# ----------------------------
'@

fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression

# Idempotency: fnm install --lts is noisy on re-runs ("Installing Node vX.Y.Z"
# immediately followed by "warning: Version already installed"). Skip it if any
# Node is already managed by fnm. Users who want to bump LTS can run
# `fnm install --lts` manually.
$fnmHasNode = ((fnm list 2>$null | Out-String) -match 'v\d+\.\d+\.\d+')
if ($fnmHasNode) {
  Write-Host "Node already managed by fnm — skipping fnm install --lts" -ForegroundColor DarkGray
} else {
  fnm install --lts
}

# Do NOT follow fnm install with `fnm use --lts` — several recent fnm builds
# from winget reject that flag form with "unexpected argument '--lts' found".
# Resolve the concrete version from `fnm current` and set it as the default
# (so new shells pick it up via the profile snippet's `fnm use default`).
$ltsCurrent = (fnm current 2>$null | Out-String).Trim()
if ($ltsCurrent -match '^v\d') {
  fnm default $ltsCurrent | Out-Null
} else {
  # Fallback for re-runs where `fnm current` reports nothing.
  fnm default lts-latest 2>$null | Out-Null
}
Need node
Need npm
node --version 2>$null | Out-Host
npm --version 2>$null | Out-Host

# pnpm via Corepack (ships with Node 16.10+). Preferred over `npm install -g
# pnpm` because Corepack manages pnpm as a shim that tracks package.json's
# packageManager field — no global npm install to conflict with per-project
# versions. https://nodejs.org/api/corepack.html
if (Get-Command corepack -ErrorAction SilentlyContinue) {
  corepack enable pnpm 2>&1 | Out-Null
  corepack prepare pnpm@latest --activate 2>&1 | Out-Null
} else {
  Write-Host "corepack not found — falling back to npm install -g pnpm" -ForegroundColor Yellow
  npm install -g pnpm
  if ($LASTEXITCODE -ne 0) {
    throw "npm install -g pnpm failed with exit code $LASTEXITCODE."
  }
}
pnpm --version 2>$null | Out-Host

Section "Python via uv (includes Python management)"
# winget avoids Zscaler/corporate-proxy blocks on irm|iex pattern
WinGetInstall "astral-sh.uv"
RefreshPath
Need "uv" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
uv --version 2>$null | Out-Host

# Idempotency: only call `uv python install 3.12` when 3.12 isn't already
# resolvable via uv. Probe safely because a missing interpreter is expected
# on fresh machines.
$uvPython = FindUvPython "3.12"
if ($uvPython.ExitCode -ne 0 -or -not $uvPython.Path) {
  uv python install 3.12
  if ($LASTEXITCODE -ne 0) {
    throw "uv python install 3.12 failed with exit code $LASTEXITCODE. Fix the error above and re-run."
  }
} else {
  Write-Host "Python 3.12 already managed by uv" -ForegroundColor DarkGray
}
# `uv python pin` is effectively idempotent but always prints; accept that.
uv python pin 3.12
if ($LASTEXITCODE -ne 0) {
  throw "uv python pin 3.12 failed with exit code $LASTEXITCODE. Fix the error above and re-run."
}

# The Microsoft Store `python.exe` alias in %LOCALAPPDATA%\Microsoft\WindowsApps
# satisfies Get-Command but errors when executed. Prepend uv's managed Python
# dir so the real interpreter resolves first.
$uvPython = FindUvPython "3.12"
$uvPythonExe = $uvPython.Path
if ($uvPythonExe -and (Test-Path $uvPythonExe)) {
  $uvPythonDir = Split-Path -Parent $uvPythonExe
  PrependPathIfExists $uvPythonDir
}

# Verify via `uv run` so we exercise uv's interpreter resolution directly,
# sidestepping any lingering WindowsApps alias on PATH.
uv run python --version 2>$null | Out-Host

Section "Bun"
# winget avoids Zscaler/corporate-proxy blocks on irm|iex pattern
WinGetInstall "Oven-sh.Bun"
RefreshPath
Need "bun" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
bun --version 2>$null | Out-Host

Section "CLI utilities"
# Fast modern replacements for classic *nix tools + TUI helpers.
# ripgrep: https://github.com/BurntSushi/ripgrep (also used internally by Claude Code)
WinGetInstall "BurntSushi.ripgrep.MSVC"
# fd: https://github.com/sharkdp/fd (fast `find` alternative)
WinGetInstall "sharkdp.fd"
# bat: https://github.com/sharkdp/bat (`cat` with syntax highlighting)
WinGetInstall "sharkdp.bat"
# jq: https://jqlang.github.io/jq/ (JSON processor)
WinGetInstall "jqlang.jq"
# fzf: https://github.com/junegunn/fzf (command-line fuzzy finder)
WinGetInstall "junegunn.fzf"
# lazygit: https://github.com/jesseduffield/lazygit (TUI for git, matches macOS bootstrap)
WinGetInstall "JesseDuffield.lazygit"
# yazi: https://yazi-rs.github.io/ (TUI file manager, matches macOS bootstrap)
WinGetInstall "sxyazi.yazi"
# PowerToys: https://github.com/microsoft/PowerToys (Windows power-user utility bundle)
WinGetInstall "Microsoft.PowerToys"
RefreshPath

Section "Claude Code"
# Auto-updating native Claude Code installer. This intentionally uses
# Anthropic's official native installer instead of WinGet because WinGet
# installs do not receive Claude Code's background auto-updates.
# https://code.claude.com/docs/en/setup

# Migration cleanup: if older runs left Claude Code installed via npm or WinGet,
# remove those package-manager copies so the auto-updating native binary is the
# sole `claude` on PATH.
if (Get-Command npm -ErrorAction SilentlyContinue) {
  $npmClaude = (npm ls -g @anthropic-ai/claude-code --depth=0 2>$null | Out-String)
  if ($npmClaude -match '@anthropic-ai/claude-code@') {
    Write-Host "Removing deprecated npm Claude Code install..." -ForegroundColor DarkGray
    npm uninstall -g @anthropic-ai/claude-code 2>&1 | Out-Null
  }
}

$wingetClaude = ''
$wingetClaudeExit = 1
try {
  $wingetClaude = (winget list --id Anthropic.ClaudeCode -e --source winget 2>&1 | Out-String)
  $wingetClaudeExit = $LASTEXITCODE
} catch {
  $wingetClaude = ''
  $wingetClaudeExit = 1
}
if ($wingetClaudeExit -eq 0 -and $wingetClaude -match [regex]::Escape('Anthropic.ClaudeCode')) {
  Write-Host "Removing WinGet Claude Code install (switching to auto-updating native installer)..." -ForegroundColor DarkGray
  winget uninstall --id Anthropic.ClaudeCode -e --source winget
}

Write-Host "Installing/updating Claude Code via Anthropic native installer..."
Invoke-Expression (Invoke-RestMethod "https://claude.ai/install.ps1")
$claudeLocalBin = Join-Path $HOME ".local\bin"
PrependPathIfExists $claudeLocalBin
RefreshPath
Need "claude" "Claude Code installed, but 'claude' is not on PATH yet. Open a new PowerShell window and rerun: claude --version"
claude --version 2>$null | Out-Host

Section "Codex CLI"
# Codex CLI has no winget package yet, so npm remains the official install path.
# Always target @latest so re-runs upgrade stale installs too.
# https://developers.openai.com/codex/cli
if (Get-Command fnm -ErrorAction SilentlyContinue) {
  fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
Write-Host "Installing/upgrading: @openai/codex@latest"
npm install -g @openai/codex@latest
if ($LASTEXITCODE -ne 0) {
  throw "npm install -g @openai/codex@latest failed with exit code $LASTEXITCODE. Fix the error above and re-run."
}
RefreshPath
Need "codex" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
codex --version 2>$null | Out-Host

$wslNeedsRerun = $false

if (-not $SkipWSL) {
  Section "WSL2"
  # Microsoft: https://learn.microsoft.com/en-us/windows/wsl/install
  $wslOutput = ''
  $wslExit = 1
  $previousErrorActionPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    $wslOutput = wsl --install 2>&1 | Out-String
    $wslExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }
  $wslOutput | Out-Host

  # Any mention of reboot/restart/"will not be effective until" in a
  # wsl --install output is treated as a reboot-required signal. A clean
  # install on a machine with WSL features already enabled produces no such
  # phrasing, so this is safe to match broadly.
  $rebootSignaled = $wslOutput -match '(?i)reboot|restart|will not be effective until'

  if ($rebootSignaled -or $wslExit -ne 0) {
    $wslNeedsRerun = $true
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Yellow
    if ($rebootSignaled) {
      Write-Host " WSL requires a system reboot before provisioning the Linux distro." -ForegroundColor Yellow
      Write-Host " Reboot Windows now, then re-run bootstrap.ps1 to finish WSL setup." -ForegroundColor Yellow
    } else {
      Write-Host " wsl --install exited with code $wslExit." -ForegroundColor Yellow
      Write-Host " Skipping second-phase WSL provisioning. Resolve the error above," -ForegroundColor Yellow
      Write-Host " reboot if needed, then re-run bootstrap.ps1." -ForegroundColor Yellow
    }
    Write-Host "================================================================" -ForegroundColor Yellow
  } else {
    wsl --set-default-version 2

    # When invoked via `irm | iex`, there is no script file on disk, so
    # $PSCommandPath is empty and the wsl/setup.sh helper is unreachable.
    # Skip the second-phase script in that case and guide the user.
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
      $repoRoot = Split-Path -Parent $PSCommandPath
      $wslScript = Join-Path $repoRoot "wsl\setup.sh"
      if (Test-Path $wslScript) {
        $wslPath = wsl wslpath -a "`"$wslScript`""
        wsl bash -lc "chmod +x $wslPath && $wslPath"
      }
    } else {
      Write-Host ""
      Write-Host "Running via 'irm | iex' — wsl/setup.sh is not on disk." -ForegroundColor Yellow
      Write-Host "To finish WSL-side setup, clone the repo and run the helper:" -ForegroundColor Yellow
      Write-Host "  git clone https://github.com/AojdevStudio/dev-bootstrap" -ForegroundColor Yellow
      Write-Host "  wsl bash -lc 'chmod +x dev-bootstrap/wsl/setup.sh && dev-bootstrap/wsl/setup.sh'" -ForegroundColor Yellow
    }
  }
}

if (-not $SkipWSL -and -not $wslNeedsRerun) {
  Section "Docker Desktop"
  # Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/
  WinGetInstall "Docker.DockerDesktop"
  RefreshPath
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    docker --version 2>$null | Out-Host
  } else {
    Write-Host "Docker Desktop installed. Open a new PowerShell window after Docker Desktop starts to use 'docker'." -ForegroundColor Yellow
  }
} elseif (-not $SkipWSL -and $wslNeedsRerun) {
  Write-Host ""
  Write-Host "Docker Desktop setup deferred until WSL finishes after reboot." -ForegroundColor Yellow
  Write-Host "Reboot Windows, then re-run the bootstrap command without -SkipWSL to install Docker Desktop." -ForegroundColor Yellow
}

Section "Finish"
if ($wslNeedsRerun) {
  Write-Host "[OK] Pre-reboot install steps completed."
} else {
  Write-Host "[OK] All install steps completed."
}
Write-Host "Open a NEW PowerShell window so PATH/profile changes load."
Write-Host "Then verify and authenticate if needed:"
Write-Host " - node --version"
Write-Host " - npm --version"
Write-Host " - uv run python --version"
Write-Host " - bun --version"
Write-Host " - claude --version (sign in / authenticate) https://code.claude.com/docs/en/setup"
Write-Host " - codex --version (sign in / authenticate) https://developers.openai.com/codex/cli"
if ($SkipWSL) {
  Write-Host ""
  Write-Host "Docker Desktop was skipped because -SkipWSL was used." -ForegroundColor Yellow
  Write-Host "To install Docker later:" -ForegroundColor Yellow
  Write-Host "  1. Open PowerShell as Administrator." -ForegroundColor Yellow
  Write-Host "  2. Run: winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
  Write-Host "  3. Open Docker Desktop, accept Docker's Subscription Service Agreement, then run: docker run hello-world" -ForegroundColor Yellow
} elseif ($wslNeedsRerun) {
  Write-Host ""
  Write-Host "After reboot, re-run the bootstrap command to finish WSL and Docker Desktop." -ForegroundColor Yellow
} else {
  Write-Host " - docker --version"
  Write-Host " - docker run hello-world (after Docker Desktop starts and terms are accepted)"
}
