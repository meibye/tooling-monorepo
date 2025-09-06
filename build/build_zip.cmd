@echo off
setlocal ENABLEEXTENSIONS

:: Build a zip artifact from a relative path under the repo and compute SHA256
:: Usage: build_zip.cmd <RepoRoot> <RelPath> <Name> <Version>
:: Example: build_zip.cmd D:\Dev\tooling-monorepo plugins\onemore\ClipTools\src onemore-ClipTools 2025.09.01
set "REPO=%~1"
set "RELP=%~2"
set "NAME=%~3"
set "VER=%~4"

if "%REPO%"=="" goto :usage
if "%RELP%"=="" goto :usage
if "%NAME%"=="" goto :usage
if "%VER%"=="" goto :usage

set "SRC=%REPO%\%RELP%"
set "OUTDIR=%REPO%\out\artifacts"
set "OUTZIP=%OUTDIR%\%NAME%-%VER%.zip"

if not exist "%SRC%" (
  echo Source path not found: %SRC%
  exit /b 1
)
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

if exist "%OUTZIP%" del /f /q "%OUTZIP%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%SRC%\*' -DestinationPath '%OUTZIP%'" || (
  echo Compress-Archive failed
  exit /b 1
)

echo Built %OUTZIP%
echo SHA256:
for /f "usebackq tokens=1-1 delims=" %%H in (`certutil -hashfile "%OUTZIP%" SHA256 ^| find /I /V "hash" ^| findstr /R "[0-9A-F][0-9A-F]"`) do echo %%H
exit /b 0

:usage
echo Usage: %~nx0 ^<RepoRoot^> ^<RelPath^> ^<Name^> ^<Version^>
exit /b 2
