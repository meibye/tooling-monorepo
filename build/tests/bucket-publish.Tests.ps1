# Unit tests for bucket-publish.ps1
Describe 'bucket-publish.ps1' {
    BeforeAll {
        $script:here = Split-Path -Parent $MyInvocation.MyCommand.Path
        Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    Mock exit {}
    
    Context 'With required Version parameter' {
        It 'Runs without error' {
            { & "$script:here/../bucket-publish.ps1" -Version '1.0.0' } | Should -Not -Throw
        }
    }
    Context 'With invalid parameter' {
        It 'Throws error for invalid parameter' {
            { & "$script:here/../bucket-publish.ps1" -Invalid foo } | Should -Throw
        }
    }
}
