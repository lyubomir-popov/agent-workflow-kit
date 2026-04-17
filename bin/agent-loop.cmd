@echo off
setlocal

pwsh -NoLogo -NoProfile -File "%~dp0..\agent-loop.ps1" -RepoRoot "%CD%" %*