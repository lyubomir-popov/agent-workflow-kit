@echo off
setlocal
set "PYTHONPATH=%~dp0..;%PYTHONPATH%"
python3 -c "import sys; sys.exit(sys.version_info < (3, 10))" >nul 2>&1
if not errorlevel 1 goto python3
python -c "import sys; sys.exit(sys.version_info < (3, 10))" >nul 2>&1
if not errorlevel 1 goto python
py -3 -c "import sys; sys.exit(sys.version_info < (3, 10))" >nul 2>&1
if not errorlevel 1 goto py
echo wfk requires Python 3.10 or newer ^(python3, python, or py^). >&2
exit /b 1
:python3
python3 -m wfk %*
exit /b %errorlevel%
:python
python -m wfk %*
exit /b %errorlevel%
:py
py -3 -m wfk %*
exit /b %errorlevel%
