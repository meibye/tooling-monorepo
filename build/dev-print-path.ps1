# dev-print-path.ps1: Print each entry in the PATH variable
$env:PATH -split ';' | ForEach-Object { Write-Host $_ }