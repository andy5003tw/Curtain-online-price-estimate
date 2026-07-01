@echo off
setlocal
set "ROOT=%~dp0"
set "SOP_HTA_TARGET=%ROOT%Weekly SOP Launcher.hta"
set "MSHTA_EXE=%SystemRoot%\System32\mshta.exe"
if not exist "%MSHTA_EXE%" set "MSHTA_EXE=mshta.exe"
REM Force reload this HTA layout only; avoid closing unrelated mshta windows.
where pwsh >nul 2>nul
if %errorlevel%==0 (
  pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$target=[System.IO.Path]::GetFullPath($env:SOP_HTA_TARGET); $needle=$target.ToLowerInvariant(); $quote=[char]34; Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'mshta.exe' -and $_.CommandLine -and (($_.CommandLine -replace $quote, '').ToLowerInvariant().Contains($needle)) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; exit 0"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$target=[System.IO.Path]::GetFullPath($env:SOP_HTA_TARGET); $needle=$target.ToLowerInvariant(); $quote=[char]34; Get-WmiObject Win32_Process | Where-Object { $_.Name -eq 'mshta.exe' -and $_.CommandLine -and (($_.CommandLine -replace $quote, '').ToLowerInvariant().Contains($needle)) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }; exit 0"
)
start "" "%MSHTA_EXE%" "%SOP_HTA_TARGET%"
