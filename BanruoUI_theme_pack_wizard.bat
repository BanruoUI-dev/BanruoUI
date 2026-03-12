@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "BASE=%~dp0"
set "NO_PAUSE="
if /I "%~1"=="--nopause" set "NO_PAUSE=1"

set "ROOT_CORE_PS1=%BASE%Theme\ThemeWizardCore.ps1"
if exist "%ROOT_CORE_PS1%" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT_CORE_PS1%"
  if errorlevel 1 (
    echo [ERROR] Update failed.
    goto :end
  )
  goto :ok
)

set /p "VERSION_INPUT=插件版本号 Version（留空保留各主题当前值）: "
set /p "INTERFACE_INPUT=游戏版本号 Interface（留空保留各主题当前值）: "

set "FOUND_ANY="
set "FAILED_ANY="
for /D %%D in ("%BASE%BanruoUI*") do (
  if exist "%%~fD\Theme\ThemeWizardCore.ps1" (
    set "FOUND_ANY=1"
    echo.
    echo ==== Processing: %%~nxD ====
    powershell -NoProfile -ExecutionPolicy Bypass -File "%%~fD\Theme\ThemeWizardCore.ps1" -VersionInput "%VERSION_INPUT%" -InterfaceInput "%INTERFACE_INPUT%" -NoPrompt
    if errorlevel 1 (
      echo [ERROR] %%~nxD update failed.
      set "FAILED_ANY=1"
    )
  )
)

if not defined FOUND_ANY (
  echo [ERROR] No Theme\ThemeWizardCore.ps1 found under %BASE%
  goto :end
)
if defined FAILED_ANY (
  echo [ERROR] One or more themes failed.
  goto :end
)

:ok
echo.
echo Done.
:end
if not defined NO_PAUSE pause
endlocal