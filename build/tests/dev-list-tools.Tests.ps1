REM Unit tests for dev-list-tools.cmd
Describe 'dev-list-tools.cmd' {
    It 'Lists tools with valid repo' {
        & cmd /c "$PSScriptRoot/../dev-list-tools.cmd defrepo"
        $LASTEXITCODE | Should -Be 0
    }
    It 'Fails with invalid repo' {
        & cmd /c "$PSScriptRoot/../dev-list-tools.cmd Z:\NotARepo"
        $LASTEXITCODE | Should -Not -Be 0
    }
}
