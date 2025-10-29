REM Unit tests for bucket-publish.cmd
Describe 'bucket-publish.cmd' {
    It 'Runs wrapper script successfully' {
        & cmd /c "$PSScriptRoot/../bucket-publish.cmd"
        $LASTEXITCODE | Should -Be 0
    }
}
