@echo off
setlocal enabledelayedexpansion

rem ===== 路径配置 =====
set "SRC=I:\Coding\BanruoUI-dev_github_clone"
set "DST=F:\WOW插件\魔兽自研插件\BanruoUI&Bre\BanruoUI&Bre成功版本"

rem ===== 生成时间戳 =====
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "TS=%%i"

rem ===== 临时工作目录 =====
set "WORK=%TEMP%\BanruoUI_archive_%TS%"
set "STAGE=%WORK%\BanruoUI_release"

echo.
echo [1/5] 创建临时目录...
mkdir "%STAGE%"

echo.
echo [2/5] 复制指定文件夹...

xcopy "%SRC%\BanruoUI" "%STAGE%\BanruoUI\" /E /I /H /Y >nul
if errorlevel 1 (
    echo 复制 BanruoUI 失败
    goto :error
)

xcopy "%SRC%\BANRUOUI[NZ]" "%STAGE%\BANRUOUI[NZ]\" /E /I /H /Y >nul
if errorlevel 1 (
    echo 复制 BANRUOUI[NZ] 失败
    goto :error
)

xcopy "%SRC%\BanruoUI_elms" "%STAGE%\BanruoUI_elms\" /E /I /H /Y >nul
if errorlevel 1 (
    echo 复制 BanruoUI_elms 失败
    goto :error
)

xcopy "%SRC%\BanruoUI_options" "%STAGE%\BanruoUI_options\" /E /I /H /Y >nul
if errorlevel 1 (
    echo 复制 BanruoUI_options 失败
    goto :error
)

echo.
echo [3/5] 生成压缩包...
set "ZIP=%DST%\BanruoUI_release_%TS%.zip"

powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%\*' -DestinationPath '%ZIP%' -Force"
if errorlevel 1 (
    echo 压缩失败
    goto :error
)

echo.
echo [4/5] 清理临时文件...
rmdir /S /Q "%WORK%"

echo.
echo [5/5] 完成
echo 已生成：
echo %ZIP%
echo.
pause
exit /b 0

:error
echo.
echo 出错，正在保留临时目录方便检查：
echo %WORK%
pause
exit /b 1