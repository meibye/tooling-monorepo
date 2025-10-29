REM Unit tests for bucket-deploy.cmd
Describe 'bucket-deploy.cmd' {
    It 'Runs wrapper script successfully' {
        & cmd /c "$PSScriptRoot/../bucket-deploy.cmd"
        $LASTEXITCODE | Should -Be 0
    }
}
