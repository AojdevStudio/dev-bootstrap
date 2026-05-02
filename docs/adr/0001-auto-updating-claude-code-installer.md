# Use Anthropic's auto-updating Claude Code installer on Windows

Windows bootstrap uses Anthropic's native `install.ps1` installer for Claude Code instead of the WinGet package because the native installer receives Claude Code background auto-updates. This deliberately trades the previous strict WinGet-only sourcing preference for fresher Claude Code installs; npm remains rejected because Anthropic marks it as deprecated and it creates avoidable Node/PATH coupling.
