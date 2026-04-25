@echo off
setlocal

pwsh -NoLogo -NoProfile -File "%~dp0..\workflow-kit.ps1" -RepoRoot "%CD%" %*
