@echo off
setlocal EnableExtensions

set "BASE=%~dp0"
set "NO_PAUSE="
if /I "%~1"=="--nopause" set "NO_PAUSE=1"

set "CORE_PS1=%BASE%Theme\ThemeWizardCore.ps1"
if not exist "%CORE_PS1%" (
  echo [ERROR] Theme\ThemeWizardCore.ps1 not found.
  goto :end
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%CORE_PS1%"
if errorlevel 1 (
  echo [ERROR] Update failed.
  goto :end
)

echo.
echo Done.
:end
if not defined NO_PAUSE pause
endlocal
