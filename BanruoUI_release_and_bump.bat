@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1

rem ===== Source and Destination =====
set "SRC=I:\Coding\BanruoUI-dev_github_clone"
set "DST=F:\WOW_project\WOW_addon\BanruoUI_Bre\BanruoUI_Bre_archive"

rem ===== Version file (saved beside this script) =====
set "VERFILE=%~dp0last_version.txt"

rem ===== Check destination exists =====
if not exist "%DST%" (
    echo ERROR: Destination folder does not exist:
    echo %DST%
    pause
    exit /b 1
)

rem ===== Init version file if missing =====
if not exist "%VERFILE%" (
    echo v1.0.0>"%VERFILE%"
)

set "LASTVER="
set /p LASTVER=<"%VERFILE%"

if "%LASTVER%"=="" (
    set "LASTVER=v1.0.0"
)

rem ===== Parse version and auto increment patch =====
set "RAW=%LASTVER%"
set "RAW=%RAW:v=%"

for /f "tokens=1,2,3 delims=." %%a in ("%RAW%") do (
    set /a MAJOR=%%a
    set /a MINOR=%%b
    set /a PATCH=%%c
)

set /a PATCH=PATCH+1
set "NEXTVER=v!MAJOR!.!MINOR!.!PATCH!"

echo.
echo =========================================
echo  BanruoUI Release + Version Update
echo =========================================
echo.
echo Last version      : %LASTVER%
echo Suggested version : %NEXTVER%
echo.

set /p VER=Enter version (press Enter to use suggested): 
if "%VER%"=="" (
    set "VER=%NEXTVER%"
)

echo.
echo Final version: %VER%
echo.

rem ===== Check source folders =====
if not exist "%SRC%\BanruoUI" (
    echo ERROR: Missing folder %SRC%\BanruoUI
    pause
    exit /b 1
)
if not exist "%SRC%\BANRUOUI[NZ]" (
    echo ERROR: Missing folder %SRC%\BANRUOUI[NZ]
    pause
    exit /b 1
)
if not exist "%SRC%\BanruoUI_elms" (
    echo ERROR: Missing folder %SRC%\BanruoUI_elms
    pause
    exit /b 1
)
if not exist "%SRC%\BanruoUI_options" (
    echo ERROR: Missing folder %SRC%\BanruoUI_options
    pause
    exit /b 1
)

echo [1/6] Update TOC versions...
set SUCCESS=0
set FAIL=0

call :update_toc "%SRC%\BanruoUI\BanruoUI.toc"
call :update_toc "%SRC%\BanruoUI_elms\BanruoUI_elms.toc"
call :update_toc "%SRC%\BanruoUI_options\BanruoUI_options.toc"
call :update_toc "%SRC%\BANRUOUI[NZ]\BanruoUI[NZ].toc"

echo.
echo TOC update result: !SUCCESS! OK / !FAIL! failed
if not "!FAIL!"=="0" (
    echo ERROR: Some TOC files failed to update
    pause
    exit /b 1
)

rem ===== Temp working folder =====
set "WORK=%TEMP%\BanruoUI_archive_temp"
set "STAGE=%WORK%\BanruoUI_release"

if exist "%WORK%" rmdir /S /Q "%WORK%"

echo.
echo [2/6] Create temp folder...
mkdir "%STAGE%"

echo.
echo [3/6] Copy selected folders...
robocopy "%SRC%\BanruoUI" "%STAGE%\BanruoUI" /E /R:1 /W:1 >nul
if errorlevel 8 goto :error

robocopy "%SRC%\BANRUOUI[NZ]" "%STAGE%\BANRUOUI[NZ]" /E /R:1 /W:1 >nul
if errorlevel 8 goto :error

robocopy "%SRC%\BanruoUI_elms" "%STAGE%\BanruoUI_elms" /E /R:1 /W:1 >nul
if errorlevel 8 goto :error

robocopy "%SRC%\BanruoUI_options" "%STAGE%\BanruoUI_options" /E /R:1 /W:1 >nul
if errorlevel 8 goto :error

echo.
echo [4/6] Create zip...
set "ZIP=%DST%\BanruoUI_%VER%.zip"

if exist "%ZIP%" (
    echo ERROR: File already exists:
    echo %ZIP%
    goto :error
)

powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%\*' -DestinationPath '%ZIP%' -Force"
if errorlevel 1 (
    echo ERROR: Compress failed
    goto :error
)

echo.
echo [5/6] Save current version...
echo %VER%>"%VERFILE%"

echo.
echo [6/6] Clean temp folder...
rmdir /S /Q "%WORK%"

echo.
echo =========================================
echo DONE
echo ZIP : %ZIP%
echo VER : %VER%
echo =========================================
echo.
pause
exit /b 0

:update_toc
set "TOC_FILE=%~1"
if not exist "!TOC_FILE!" (
    echo [ERROR] Not found: !TOC_FILE!
    set /a FAIL+=1
    goto :eof
)

powershell -NoProfile -Command ^
  "$p = '!TOC_FILE!';" ^
  "$v = '%VER%';" ^
  "$c = Get-Content -LiteralPath $p;" ^
  "$c = $c -replace '(?m)^## Version: .*', ('## Version: ' + $v);" ^
  "Set-Content -LiteralPath $p -Value $c -Encoding UTF8"

if errorlevel 1 (
    echo [ERROR] Failed: !TOC_FILE!
    set /a FAIL+=1
    goto :eof
)

echo [OK] !TOC_FILE! -> %VER%
set /a SUCCESS+=1
goto :eof

:error
echo.
echo ERROR occurred. Temp folder kept for checking:
echo %WORK%
pause
exit /b 1