# Unit tests for bucket-clean-artifacts.ps1
Describe 'bucket-clean-artifacts.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    Mock exit {}
    
    Context 'With default parameters' {
        It 'Runs without error' {
            { & "$script:here/../bucket-clean-artifacts.ps1" } | Should -Not -Throw
        }
    }
    Context 'With invalid parameter' {
        It 'Throws error for invalid parameter' {
            { & "$script:here/../bucket-clean-artifacts.ps1" -Invalid foo } | Should -Throw
        }
    }
}
