# Unit tests for dev-touch-file.ps1
Describe 'dev-touch-file.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Set-ItemProperty {}
    Mock Write-Host {}
    
    Context 'When file exists' {
        Mock Test-Path { $true }
        It 'Updates LastWriteTime for the file' {
            & "$script:here/../dev-touch-file.ps1" -Path 'C:\test.txt'
            Assert-MockCalled Set-ItemProperty -Exactly 1 -Scope It
        }
    }
    Context 'When file does not exist' {
        Mock Test-Path { $false }
        It 'Throws error and exits' {
            { & "$script:here/../dev-touch-file.ps1" -Path 'C:\notfound.txt' } | Should -Throw
        }
    }
}
