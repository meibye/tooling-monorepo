@echo off
set "SCRIPT_PATH=D:\Dev\meibye-bucket\scripts\scan-update-bucket.ps1"
if not exist "%SCRIPT_PATH%" (
    set "SCRIPT_PATH=C:\Dev\meibye-bucket\scripts\scan-update-bucket.ps1"
)

REM Echo which script will be run
echo Running: %SCRIPT_PATH%

if exist "%SCRIPT_PATH%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %*
) else (
    echo Script not found on D: or C: drive.
    exit /b 1
)

REM Check for errors
if errorlevel 1 (
    echo.
    echo [ERROR] scan-update-bucket.ps1 failed.
    exit /b 1
)

endlocal
exit /b 0
