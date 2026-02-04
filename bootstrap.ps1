<#
Windows-first bootstrap.

Canonical sources:
- WSL: https://learn.microsoft.com/en-us/windows/wsl/install
- uv: https://docs.astral.sh/uv/getting-started/installation/
- Bun: https://bun.com/docs/installation
- Claude Code: https://code.claude.com/docs/en/setup
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
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($machinePath -and $userPath) {
    $env:Path = "$machinePath;$userPath"
  } elseif ($machinePath) {
    $env:Path = $machinePath
  } elseif ($userPath) {
    $env:Path = $userPath
  }
}

function WinGetInstall([string]$id) {
  Write-Host "Installing: $id"
  winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements
}

function EnsureProfileSnippet([string]$marker, [string]$snippet) {
  $profileDir = Split-Path -Parent $PROFILE
  if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir | Out-Null }
  if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE | Out-Null }

  $content = Get-Content $PROFILE -Raw
  if ($content -notmatch [regex]::Escape($marker)) {
    Add-Content -Path $PROFILE -Value "`n$snippet`n"
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
  fnm env --use-on-cd | Out-String | Invoke-Expression
}
# ----------------------------
'@

fnm env --use-on-cd | Out-String | Invoke-Expression
fnm install --lts
fnm default lts-latest
Need node
Need npm
node --version 2>$null | Out-Host
npm --version 2>$null | Out-Host

Section "Python via uv (includes Python management)"
# Official uv PowerShell install: https://docs.astral.sh/uv/getting-started/installation/
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
RefreshPath
Need "uv" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
uv --version 2>$null | Out-Host
uv python install 3.12
uv python pin 3.12
Need "python" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
python --version 2>$null | Out-Host

Section "Bun"
# Official Bun PowerShell install: https://bun.com/docs/installation
powershell -c "irm bun.sh/install.ps1 | iex"
RefreshPath
Need "bun" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
bun --version 2>$null | Out-Host

Section "Claude Code"
# Official setup docs: https://code.claude.com/docs/en/setup
irm https://claude.ai/install.ps1 | iex
RefreshPath
Need "claude" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
claude --version 2>$null | Out-Host

Section "Codex CLI"
# Official Codex CLI docs: https://developers.openai.com/codex/cli
npm install -g @openai/codex
RefreshPath
Need "codex" "If this is your first run, open a new PowerShell window and rerun so PATH updates apply."
codex --version 2>$null | Out-Host

if (-not $SkipWSL) {
  Section "WSL2"
  # Microsoft: https://learn.microsoft.com/en-us/windows/wsl/install
  wsl --install
  wsl --set-default-version 2

  $repoRoot = Split-Path -Parent $PSCommandPath
  $wslScript = Join-Path $repoRoot "wsl\setup.sh"
  if (Test-Path $wslScript) {
    $wslPath = wsl wslpath -a "`"$wslScript`""
    wsl bash -lc "chmod +x $wslPath && $wslPath"
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
