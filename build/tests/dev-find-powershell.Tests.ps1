REM Unit tests for dev-find-powershell.cmd
Describe 'dev-find-powershell.cmd' {
    It 'Finds and runs a PowerShell script' {
        & cmd /c "$PSScriptRoot/../dev-find-powershell.cmd dev-touch-file ps1 -Path test.txt"
        $LASTEXITCODE | Should -Be 0
    }
}
