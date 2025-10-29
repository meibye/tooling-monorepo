REM Unit tests for bucket-scan-update.cmd
Describe 'bucket-scan-update.cmd' {
    It 'Runs wrapper script successfully' {
        & cmd /c "$PSScriptRoot/../bucket-scan-update.cmd"
        $LASTEXITCODE | Should -Be 0
    }
}
