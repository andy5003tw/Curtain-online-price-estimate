@echo off
setlocal
set "ROOT=%~dp0"
echo Running Weekly SOP...
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%run-weekly.ps1"
echo.
if errorlevel 1 (
  echo Weekly SOP failed. Check the error above.
) else (
  echo Weekly SOP done.
)
pause
