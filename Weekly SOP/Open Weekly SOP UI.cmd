@echo off
setlocal
set "ROOT=%~dp0"
REM Force reload latest HTA layout by closing existing Weekly SOP HTA window first
powershell -NoProfile -ExecutionPolicy Bypass -Command "$targets = Get-Process -Name mshta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like '*Weekly SOP*' -or $_.MainWindowTitle -like '*Weekly SOP Launcher*' }; if ($targets) { $targets | Stop-Process -Force }; exit 0"
mshta "%ROOT%Weekly SOP Launcher.hta"
