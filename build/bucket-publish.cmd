@echo off
setlocal

REM bucket-publish.cmd: Wrapper for bucket-publish.ps1

REM Extract file name without extension
set "CUR_FILE=%~nx0"
for %%F in ("%CUR_FILE%") do set "CUR_FILE_NOEXT=%%~nF"
@REM echo Calling: "%~dp0dev-find-powershell.cmd" "%CUR_FILE_NOEXT%" "ps1" %*
@REM pause
call "%~dp0dev-find-powershell.cmd" "%CUR_FILE_NOEXT%" "ps1" %*

REM Call the found script and check for errors
if errorlevel 1 (
    echo [ERROR] Failed execution of "%~dp0dev-find-powershell.cmd" "%CUR_FILE_NOEXT%" "ps1" %*.
    exit /b 1
)

endlocal
exit /b 0