# Unit tests for bucket-deploy.ps1
Describe 'bucket-deploy.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    Mock exit {}
    
    Context 'With default parameters' {
        It 'Runs without error' {
            { & "$script:here/../bucket-deploy.ps1" } | Should -Not -Throw
        }
    }
    Context 'With invalid parameter' {
        It 'Throws error for invalid parameter' {
            { & "$script:here/../bucket-deploy.ps1" -Invalid foo } | Should -Throw
        }
    }
}
