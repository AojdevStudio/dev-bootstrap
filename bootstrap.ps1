<#
Windows-first bootstrap.

Canonical sources:
- WSL: https://learn.microsoft.com/en-us/windows/wsl/install
- uv: https://github.com/microsoft/winget-pkgs (astral-sh.uv)
- Bun: https://github.com/microsoft/winget-pkgs (Oven-sh.Bun)
- Claude Code: https://www.npmjs.com/package/@anthropic-ai/claude-code
- Codex CLI: https://developers.openai.com/codex/cli
- Git for Windows: https://git-scm.com/download/win
- winget: https://learn.microsoft.com/en-us/windows/package-manager/winget/
#>

[CmdletBinding()]
param(
  [switch]$SkipWSL
)

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

  Write-Host "Re-launching as Administrator (needed to enable WSL)..." -ForegroundColor Yellow
  $args = @(
    "-NoProfile",
    "-ExecutionPolicy","Bypass",
    "-File","`"$PSCommandPath`""
  ) + $MyInvocation.UnboundArguments

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
fnm install --lts
# `fnm install --lts` activates the version in the current shell's multishell
# junction. Do NOT follow with `fnm use --lts` — several recent fnm builds from
# winget reject that flag form with "unexpected argument '--lts' found".
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

Section "Python via uv (includes Python management)"
# winget avoids Zscaler/corporate-proxy blocks on irm|iex pattern
WinGetInstall "astral-sh.uv"
RefreshPath
Need "uv" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
uv --version 2>$null | Out-Host
uv python install 3.12
uv python pin 3.12

# The Microsoft Store `python.exe` alias in %LOCALAPPDATA%\Microsoft\WindowsApps
# satisfies Get-Command but errors when executed. Prepend uv's managed Python
# dir so the real interpreter resolves first.
$uvPythonExe = (uv python find 3.12 2>$null)
if ($uvPythonExe -and (Test-Path $uvPythonExe)) {
  $uvPythonDir = Split-Path -Parent $uvPythonExe
  if (-not (($env:Path -split ';') -contains $uvPythonDir)) {
    $env:Path = "$uvPythonDir;$env:Path"
  }
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

Section "Claude Code"
# Re-activate fnm in this session: winget installs in earlier sections can
# spawn sub-shells that drop the fnm multishells junction from PATH, leaving
# `npm` reachable but its globals prefix invisible to later commands.
if (Get-Command fnm -ErrorAction SilentlyContinue) {
  fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
# npm avoids Zscaler/corporate-proxy blocks on irm|iex pattern
npm install -g @anthropic-ai/claude-code
if ($LASTEXITCODE -ne 0) {
  throw "npm install -g @anthropic-ai/claude-code failed with exit code $LASTEXITCODE. Fix the error above and re-run."
}
RefreshPath
Need "claude" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
claude --version 2>$null | Out-Host

Section "Codex CLI"
if (Get-Command fnm -ErrorAction SilentlyContinue) {
  fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression
}
# Official Codex CLI docs: https://developers.openai.com/codex/cli
npm install -g @openai/codex
if ($LASTEXITCODE -ne 0) {
  throw "npm install -g @openai/codex failed with exit code $LASTEXITCODE. Fix the error above and re-run."
}
RefreshPath
Need "codex" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
codex --version 2>$null | Out-Host

if (-not $SkipWSL) {
  Section "WSL2"
  # Microsoft: https://learn.microsoft.com/en-us/windows/wsl/install
  $wslOutput = wsl --install 2>&1 | Out-String
  $wslExit = $LASTEXITCODE
  $wslOutput | Out-Host

  $rebootSignaled = $wslOutput -match '(?i)(reboot|restart) (is )?required|(reboot|restart) (your|the) (computer|system|machine)'

  if ($rebootSignaled -or $wslExit -ne 0) {
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

    $repoRoot = Split-Path -Parent $PSCommandPath
    $wslScript = Join-Path $repoRoot "wsl\setup.sh"
    if (Test-Path $wslScript) {
      $wslPath = wsl wslpath -a "`"$wslScript`""
      wsl bash -lc "chmod +x $wslPath && $wslPath"
    }
  }
}

Section "Finish"
Write-Host "[OK] All install steps completed."
Write-Host "Open a NEW PowerShell window so PATH/profile changes load."
Write-Host "Then verify and authenticate if needed:"
Write-Host " - node --version"
Write-Host " - npm --version"
Write-Host " - python --version"
Write-Host " - bun --version"
Write-Host " - claude --version (sign in / authenticate) https://code.claude.com/docs/en/setup"
Write-Host " - codex --version (sign in / authenticate) https://developers.openai.com/codex/cli"
