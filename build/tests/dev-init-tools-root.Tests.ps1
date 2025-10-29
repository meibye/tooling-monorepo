REM Unit tests for dev-init-tools-root.cmd
Describe 'dev-init-tools-root.cmd' {
    It 'Initializes tools root with default path' {
        & cmd /c "$PSScriptRoot/../dev-init-tools-root.cmd"
        $LASTEXITCODE | Should -Be 0
    }
    It 'Initializes tools root with custom path' {
        & cmd /c "$PSScriptRoot/../dev-init-tools-root.cmd D:\ToolsTest"
        $LASTEXITCODE | Should -Be 0
    }
}
