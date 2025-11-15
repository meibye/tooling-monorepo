<# Wrapper for One-Click Installer #>
if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") -eq $false) {
    Write-Host "Please run this script as Administrator." –ForegroundColor Red
    exit 1
}

# Set execution policy to allow this script to run (you can restore later)
Set-ExecutionPolicy Bypass –Scope Process –Force

# Call the real setup script
& .\install-all-ai-hybrid-tools.ps1

# Optionally create a desktop shortcut or message
Write-Host "Installation complete. You may need to restart your machine." –ForegroundColor Green
