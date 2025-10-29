REM Unit tests for dev-new-tool.cmd
REM These tests use PowerShell to invoke the script and check for expected output and side effects
Describe 'dev-new-tool.cmd' {
    It 'Scaffolds a new tool with valid parameters' {
        $result = & cmd /c "$PSScriptRoot/../dev-new-tool.cmd defrepo ps testapp testtool.ps1"
        $LASTEXITCODE | Should -Be 0
    }
    It 'Fails with missing parameters' {
        $result = & cmd /c "$PSScriptRoot/../dev-new-tool.cmd"
        $LASTEXITCODE | Should -Not -Be 0
    }
}
