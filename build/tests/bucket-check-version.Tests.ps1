# Unit tests for bucket-check-version.ps1
Describe 'bucket-check-version.ps1' {
    BeforeAll {
        $script:here = Split-Path -Path $PSScriptRoot -Parent
        # Write-Host "[TEST] Value of `$here: $script:here"
    }
    Mock Write-Error {}
    Mock Write-Host {}
    Mock exit {}
    
    Context 'With default parameters' {
        It 'Runs without error' {
            { & "$script:here/bucket-check-version.ps1" } | Should -Not -Throw
        }
        It 'Runs without error and outputs expected headlines' {
            $output = & "$script:here/bucket-check-version.ps1" *>&1
            write-host "[TEST] Output:`n$output"
            $output | Should -Contain 'Family'
            # $output | Should -Match '^-{10,}'
        }
    }
    Context 'With invalid parameter' {
        It 'Returns expected error message for invalid parameter' {
            $output = & "$script:here/bucket-check-version.ps1" -Invalid foo *>&1
            $output | Should -Contain 'Invalid argument(s): Invalid Supported arguments: -Family -App -Tool'
        }
    }
}
