REM Unit tests for dev-init-monorepo.cmd
Describe 'dev-init-monorepo.cmd' {
    It 'Initializes monorepo with default path' {
        & cmd /c "$PSScriptRoot/../dev-init-monorepo.cmd"
        $LASTEXITCODE | Should -Be 0
    }
    It 'Initializes monorepo with defrepo' {
        & cmd /c "$PSScriptRoot/../dev-init-monorepo.cmd defrepo"
        $LASTEXITCODE | Should -Be 0
    }
}
