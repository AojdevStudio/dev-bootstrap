[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$requiredPaths = @(
  'README.md',
  'LICENSE',
  'bootstrap.ps1',
  'wsl/setup.sh',
  'macos/bootstrap.sh',
  'macos/zshrc.snippet.sh',
  'scripts/check-structure.ps1',
  'scripts/check-structure.sh',
  '.github/workflows/repo-health.yml'
)

$missing = @()
foreach ($p in $requiredPaths) {
  if (-not (Test-Path $p)) { $missing += $p }
}

if ($missing.Count -gt 0) {
  Write-Error ("Missing required paths:`n - " + ($missing -join "`n - "))
}

Write-Host "OK: repo structure looks correct." -ForegroundColor Green
