# monitor_ai.ps1
# Refreshes every 2 seconds to show GPU and Ollama status

Function Get-OllamaStatus {
    Write-Host "`n--- OLLAMA LOAD STATUS ---" -ForegroundColor Cyan
    ollama ps
}

Function Get-GPUStatus {
    Write-Host "--- NVIDIA RTX 3090 STATS ---" -ForegroundColor Green
    # Queries: Utilization, Used VRAM, Total VRAM, and Temperature
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits | ForEach-Object {
        $stats = $_.Split(',')
        Write-Host "GPU Load: $($stats[0])% | VRAM: $($stats[1])MB / $($stats[2])MB | Temp: $($stats[3])°C" -ForegroundColor Yellow
    }
}

while($true) {
    Clear-Host
    Write-Host "DeepSeek-R1 Monitor (Ctrl+C to Exit)" -ForegroundColor White -BackgroundColor DarkBlue
    Get-GPUStatus
    Get-OllamaStatus
    
    Write-Host "`n--- PERFORMANCE TIP ---" -ForegroundColor Gray
    Write-Host "If VRAM > 23000MB, you are at the limit. Close Chrome/VS Code to free space."
    
    Start-Sleep -Seconds 2
}