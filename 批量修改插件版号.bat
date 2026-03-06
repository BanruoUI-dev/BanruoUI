@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

echo.
echo =========================================
echo  BanruoUI Version Update
echo =========================================
echo.

set /p NEW_VER=Enter new version (e.g. v2.0.16): 

if "!NEW_VER!"=="" (
  echo [ERROR] Version cannot be empty
  pause
  exit /b 1
)

echo.
echo New version: !NEW_VER!
echo -----------------------------------------

set "SCRIPT_DIR=%~dp0"
set SUCCESS=0
set FAIL=0

call :update_toc "BanruoUI\BanruoUI.toc"
call :update_toc "BanruoUI_elms\BanruoUI_elms.toc"
call :update_toc "BanruoUI_options\BanruoUI_options.toc"
call :update_toc "BANRUOUI[NZ]\BanruoUI[NZ].toc"

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

powershell -NoProfile -Command "(Get-Content -LiteralPath '!TOC_FILE!') -replace '(?m)^## Version: .*', '## Version: !NEW_VER!' | Set-Content -LiteralPath '!TOC_FILE!'"
if errorlevel 1 (
  echo [ERROR] Failed: %~1
  set /a FAIL+=1
  goto :eof
)

echo [OK] %~1 -^> !NEW_VER!
set /a SUCCESS+=1
goto :eof
