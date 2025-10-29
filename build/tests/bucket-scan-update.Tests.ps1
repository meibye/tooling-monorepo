# Unit tests for bucket-scan-update.ps1
Describe 'bucket-scan-update.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    Mock exit {}
    
    Context 'With no arguments' {
        It 'Runs without error' {
            { & "$script:here/../bucket-scan-update.ps1" } | Should -Not -Throw
        }
    }
    Context 'With -NoPublish' {
        It 'Runs without error' {
            { & "$script:here/../bucket-scan-update.ps1" -NoPublish } | Should -Not -Throw
        }
    }
    Context 'With invalid parameter' {
        It 'Throws error for invalid parameter' {
            { & "$script:here/../bucket-scan-update.ps1" -Invalid foo } | Should -Throw
        }
    }
}
