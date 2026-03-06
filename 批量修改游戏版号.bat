@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

echo.
echo =========================================
echo  BanruoUI Interface Update
echo =========================================
echo.

set /p NEW_IFACE=Enter new interface (e.g. 120100): 

if "!NEW_IFACE!"=="" (
  echo [ERROR] Interface cannot be empty
  pause
  exit /b 1
)

echo.
echo New interface: !NEW_IFACE!
echo -----------------------------------------

set "SCRIPT_DIR=%~dp0"
set SUCCESS=0
set FAIL=0

call :update_toc "BanruoUI\BanruoUI.toc"
call :update_toc "BanruoUI_elms\BanruoUI_elms.toc"
call :update_toc "BanruoUI_options\BanruoUI_options.toc"
call :update_toc "BanruoUI[NZ]\BanruoUI[NZ].toc"

echo.
echo =========================================
echo  Done: !SUCCESS! OK / !FAIL! skipped
echo =========================================
echo.
pause
exit /b 0

:update_toc
set "TOC_FILE=%SCRIPT_DIR%%~1"
if not exist "!TOC_FILE!" (
  echo [SKIP] Not found: %~1
  set /a FAIL+=1
  goto :eof
)

powershell -NoProfile -Command "(Get-Content -LiteralPath '!TOC_FILE!') -replace '(?m)^## Interface: .*', '## Interface: !NEW_IFACE!' | Set-Content -LiteralPath '!TOC_FILE!'"
if errorlevel 1 (
  echo [ERROR] Failed: %~1
  set /a FAIL+=1
  goto :eof
)

echo [OK] %~1 -^> !NEW_IFACE!
set /a SUCCESS+=1
goto :eof

