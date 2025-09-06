@echo off
setlocal ENABLEEXTENSIONS

:: Update a bucket manifest (version/url/hash), commit and push
:: Usage: update_bucket_manifest.cmd <BucketRepoRoot> <AppJsonName> <Version> <Url> <Sha256> [CommitMessage]
:: Example:
::   update_bucket_manifest.cmd D:\Dev\meibye-bucket onemore-ClipTools.json 2025.09.01 https://artifacts/onemore-ClipTools-2025.09.01.zip ABCD1234... "onemore-ClipTools 2025.09.01"
set "BUCKET=%~1"
set "APPJSON=%~2"
set "VER=%~3"
set "URL=%~4"
set "SHA=%~5"
set "MSG=%~6"

if "%BUCKET%"=="" goto :usage
if "%APPJSON%"=="" goto :usage
if "%VER%"=="" goto :usage
if "%URL%"=="" goto :usage
if "%SHA%"=="" goto :usage
if "%MSG%"=="" set "MSG=%APPJSON% %VER%"

set "FILE=%BUCKET%\bucket\%APPJSON%"
if not exist "%FILE%" (
  echo Manifest not found: %FILE%
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p='%FILE%'; $j=Get-Content $p -Raw | ConvertFrom-Json; " ^
  "$j.version='%VER%'; " ^
  "if($j.architecture.'64bit'){ $j.architecture.'64bit'.url='%URL%'; $j.architecture.'64bit'.hash='sha256:%SHA%'; } " ^
  "elseif($j.url){ $j.url='%URL%'; $j.hash='sha256:%SHA%'; } " ^
  "$j | ConvertTo-Json -Depth 8 | Out-File -Encoding UTF8 $p"

if errorlevel 1 (
  echo Failed to update JSON.
  exit /b 1
)

pushd "%BUCKET%"
git add "bucket\%APPJSON%"
git commit -m "%MSG%"
if errorlevel 1 (
  echo Git commit failed (maybe nothing changed?).
)
git push
popd

echo Updated %APPJSON% to %VER% and pushed.
exit /b 0

:usage
echo Usage: %~nx0 ^<BucketRepoRoot^> ^<AppJsonName^> ^<Version^> ^<Url^> ^<Sha256^> [CommitMessage]
exit /b 2
