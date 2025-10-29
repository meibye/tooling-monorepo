REM Unit tests for dev-new-plugin.cmd
Describe 'dev-new-plugin.cmd' {
    It 'Scaffolds a new plugin with valid parameters' {
        & cmd /c "$PSScriptRoot/../dev-new-plugin.cmd defrepo testplugin"
        $LASTEXITCODE | Should -Be 0
    }
    It 'Fails with missing parameters' {
        & cmd /c "$PSScriptRoot/../dev-new-plugin.cmd"
        $LASTEXITCODE | Should -Not -Be 0
    }
}
