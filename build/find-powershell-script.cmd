@echo off
setlocal

REM Arguments: %1 = script file name without extension (e.g., auto-update-tools)
REM            %2 = script file extension (e.g., ps1)
REM            %3... = arguments to pass to PowerShell script

set "CUR_DRIVE=%~d0"
set "CUR_FOLDER=%~p0"
set "CUR_FILE_NOEXT=%~1"
set "CUR_EXT=%~2"
set "SCRIPT_REL_PATH=%CUR_FOLDER%%CUR_FILE_NOEXT%.%CUR_EXT%"

set "DRIVES_LIST=%CUR_DRIVE:~0,1% C D E F G H I J K L M N O P Q R S T U V W X Y Z"

setlocal enabledelayedexpansion
set "UNIQUE_DRIVES="
for %%D in (%DRIVES_LIST%) do (
    if "!UNIQUE_DRIVES!"=="" (
        set "UNIQUE_DRIVES=%%D"
    ) else (
        echo !UNIQUE_DRIVES! | findstr /i /c:"%%D" >nul
        if errorlevel 1 (
            set "UNIQUE_DRIVES=!UNIQUE_DRIVES! %%D"
        )
    )
)

set "SCRIPT_PATH="
for %%D in (!UNIQUE_DRIVES!) do (
    if not defined SCRIPT_PATH (
        if exist "%%D:%SCRIPT_REL_PATH%" (
            set "SCRIPT_PATH=%%D:%SCRIPT_REL_PATH%"
        )
    )
)

endlocal & set "SCRIPT_PATH=%SCRIPT_PATH%"

REM Remove first two arguments (script name and extension)
shift
shift

REM Build argument string from remaining arguments
set "PS_ARGS="
:collect_args
if "%~1"=="" goto run_ps
set PS_ARGS=%PS_ARGS% %1
shift
goto collect_args

:run_ps
REM If script not found, print error and exit
if not defined SCRIPT_PATH (
    echo [ERROR] Script not found on any drive.
    exit /b 1
)

REM Print which script will be executed
echo Running: %SCRIPT_PATH%

REM Prefer pwsh.exe if available, fallback to powershell.exe
where pwsh >nul 2>nul
if %errorlevel%==0 (
    set "PS_EXEC=pwsh"
) else (
    set "PS_EXEC=powershell"
)

@REM echo %PS_EXEC% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %PS_ARGS%
@REM pause
%PS_EXEC% -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" %PS_ARGS%

REM If PowerShell script failed, print error and exit
if errorlevel 1 (
    echo.
    echo [ERROR] %CUR_FILE_NOEXT%.ps1 failed.
    exit /b 1
)

exit /b 0
