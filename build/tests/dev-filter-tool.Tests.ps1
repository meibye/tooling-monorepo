# Unit tests for dev-filter-tool.ps1
Describe 'dev-filter-tool.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    
    Context 'With valid parameters' {
        It 'Runs without error' {
            { & "$script:here/../dev-filter-tool.ps1" -Family ps -App myapp -Tool '*.ps1' } | Should -Not -Throw
        }
    }
    Context 'With invalid parameter' {
        It 'Throws error for invalid parameter' {
            { & "$script:here/../dev-filter-tool.ps1" -InvalidParam foo } | Should -Throw
        }
    }
}
