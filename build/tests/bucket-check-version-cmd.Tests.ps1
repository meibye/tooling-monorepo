# Unit tests for bucket-check-version.cmd
Describe 'bucket-check-version.cmd' {
    It 'Runs wrapper script successfully' {
        & cmd /c "$PSScriptRoot/../bucket-check-version.cmd"
        $LASTEXITCODE | Should -Be 0
    }
}
