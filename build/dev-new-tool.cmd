@echo off
setlocal ENABLEEXTENSIONS

:: -----------------------------------------------------------------------------
:: dev-new-tool.cmd
::
:: Scaffolds a new standalone tool or adds a tool to a tool group in the monorepo.
::
:: Usage:
::   dev-new-tool.cmd <RepoRoot|defrepo> <Family> <App> [Tool]
::
:: Parameters:
::   RepoRoot   - Root path of the repo, or 'defrepo' to auto-select D: or C:.
::   Family     - Tool type: ps, py, cmd, bash, zsh.
::   App        - Folder grouping for related tools.
::   Tool       - (Optional) Name for the tool source file. If omitted, App is used.
::
:: Behavior:
::   - Creates the folder structure for the tool group if it doesn't exist.
::   - Creates a tool source file if it doesn't exist, using Tool or App.
::   - Creates or appends to a README.md in the tool group folder.
::
:: Examples:
::   dev-new-tool.cmd defrepo ps ai_kb
::   dev-new-tool.cmd D:\Dev\tooling-monorepo py ingest_tools ingest_pdf
:: -----------------------------------------------------------------------------

set "REPO=%~1"
set "FAMILY=%~2"
set "APP=%~3"
set "TOOL=%~4"

:: Handle default repo if 'defrepo' is given
if /I "%REPO%"=="defrepo" (
    if exist "D:\" (
        set "REPO=D:\Dev\tooling-monorepo"
    ) else (
        set "REPO=C:\Dev\tooling-monorepo"
    )
)

if "%REPO%"=="" goto :usage
if "%FAMILY%"=="" goto :usage
if "%APP%"=="" goto :usage

set "BASE=%REPO%\tools\%FAMILY%\%APP%\src"
set "TOOLDIR=%REPO%\tools\%FAMILY%\%APP%"

:: Determine tool file name
if not "%TOOL%"=="" (
    set "TOOLFILE=%TOOL%"
) else (
    set "TOOLFILE=%APP%"
)

:: Create folder structure if not exists
if not exist "%REPO%\tools" (
    mkdir "%REPO%\tools" || (echo Failed to create %REPO%\tools & exit /b 1)
)
if not exist "%REPO%\tools\%FAMILY%" (
    mkdir "%REPO%\tools\%FAMILY%" || (echo Failed to create %REPO%\tools\%FAMILY% & exit /b 1)
)
if not exist "%TOOLDIR%" (
    mkdir "%TOOLDIR%" || (echo Failed to create %TOOLDIR% & exit /b 1)
)
if not exist "%BASE%" (
    mkdir "%BASE%" || (echo Failed to create %BASE% & exit /b 1)
) else (
    echo Folder "%BASE%" already exists.
)

:: Create tool source file if not exists, else inform user
if /I "%FAMILY%"=="ps" (
    if exist "%BASE%\%TOOLFILE%.ps1" (
        echo "%BASE%\%TOOLFILE%.ps1" already exists.
    ) else (
        > "%BASE%\%TOOLFILE%.ps1" (echo param^(^) && echo Write-Output "%TOOLFILE%")
        echo Created "%BASE%\%TOOLFILE%.ps1"
    )
)
if /I "%FAMILY%"=="py" (
    if exist "%BASE%\%TOOLFILE%.py" (
        echo "%BASE%\%TOOLFILE%.py" already exists.
    ) else (
        > "%BASE%\%TOOLFILE%.py" echo print("%TOOLFILE%")
        echo Created "%BASE%\%TOOLFILE%.py"
    )
)
if /I "%FAMILY%"=="cmd" (
    if exist "%BASE%\%TOOLFILE%.cmd" (
        echo "%BASE%\%TOOLFILE%.cmd" already exists.
    ) else (
        > "%BASE%\%TOOLFILE%.cmd" (echo @echo off && echo %%~n0)
        echo Created "%BASE%\%TOOLFILE%.cmd"
    )
)
if /I "%FAMILY%"=="bash" (
    if exist "%BASE%\%TOOLFILE%.sh" (
        echo "%BASE%\%TOOLFILE%.sh" already exists.
    ) else (
        > "%BASE%\%TOOLFILE%.sh" (echo #!/usr/bin/env bash && echo %TOOLFILE%)
        echo Created "%BASE%\%TOOLFILE%.sh"
    )
)
if /I "%FAMILY%"=="zsh" (
    if exist "%BASE%\%TOOLFILE%.zsh" (
        echo "%BASE%\%TOOLFILE%.zsh" already exists.
    ) else (
        > "%BASE%\%TOOLFILE%.zsh" (echo #!/usr/bin/env zsh && echo %TOOLFILE%)
        echo Created "%BASE%\%TOOLFILE%.zsh"
    )
)

:: Create or update README.md
if exist "%TOOLDIR%\README.md" (
    echo Appending to "%TOOLDIR%\README.md"
    >> "%TOOLDIR%\README.md" echo * %TOOLFILE% (%FAMILY% tool^)
) else (
    > "%TOOLDIR%\README.md" echo ## %APP% tools
    >> "%TOOLDIR%\README.md" echo
    >> "%TOOLDIR%\README.md" echo * %TOOLFILE% (%FAMILY% tool^)
    echo Created "%TOOLDIR%\README.md"
)

echo Created or verified %FAMILY% tool skeleton at %TOOLDIR%
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^|defrepo^> ^<Family^> ^<App^> [Tool]
echo        defrepo: uses default repo path based on drive D: or C:
echo        Family:  ps, py, cmd, bash, zsh
echo        App:     folder grouping for related tools
echo        Tool:    (optional) name for the tool source file
exit /b 2
