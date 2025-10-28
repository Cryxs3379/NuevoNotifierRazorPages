# Script de prueba para el InboxWatcher + SSE
Write-Host "=== Prueba del InboxWatcher + SSE ===" -ForegroundColor Cyan

# Función para probar el stream SSE con timeout
function Test-SSEStream {
    param([string]$url, [int]$timeoutSeconds = 10)
    
    Write-Host "`nConectando al stream SSE por $timeoutSeconds segundos..." -ForegroundColor Yellow
    Write-Host "URL: $url" -ForegroundColor Gray
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "GET"
        $request.Timeout = $timeoutSeconds * 1000
        
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        $startTime = Get-Date
        $eventCount = 0
        
        while (-not $reader.EndOfStream -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
            $line = $reader.ReadLine()
            if ($line -and $line.StartsWith("data: ")) {
                $json = $line.Substring(6)
                $eventCount++
                Write-Host "[$eventCount] Evento recibido: $json" -ForegroundColor Green
            }
        }
        
        Write-Host "`nTotal de eventos recibidos: $eventCount" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Error en el stream: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        if ($reader) { $reader.Close() }
        if ($stream) { $stream.Close() }
        if ($response) { $response.Close() }
    }
}

# Verificar que la API está funcionando
Write-Host "Verificando API..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5080/api/health"
    Write-Host "API Status: $($health.status)" -ForegroundColor Green
    Write-Host "Esendex Configurado: $($health.esendexConfigured)" -ForegroundColor Green
}
catch {
    Write-Host "Error conectando a la API: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verificar configuración del watcher
Write-Host "`nVerificando configuración del watcher..." -ForegroundColor Yellow
try {
    $config = Get-Content "appsettings.json" | ConvertFrom-Json
    $watcher = $config.Watcher
    Write-Host "Watcher Enabled: $($watcher.Enabled)" -ForegroundColor Green
    Write-Host "Interval Seconds: $($watcher.IntervalSeconds)" -ForegroundColor Green
    Write-Host "Account Ref: $($watcher.AccountRef)" -ForegroundColor Green
}
catch {
    Write-Host "Error leyendo configuración: $($_.Exception.Message)" -ForegroundColor Red
}

# Probar el stream SSE
Write-Host "`n=== Probando Stream SSE ===" -ForegroundColor Cyan
Write-Host "El watcher debería estar ejecutándose cada $($watcher.IntervalSeconds) segundos..." -ForegroundColor Yellow
Write-Host "Conectando al stream para ver eventos en tiempo real..." -ForegroundColor Yellow

Test-SSEStream "http://localhost:5080/api/v1/stream/messages" 15

Write-Host "`n=== Prueba completada ===" -ForegroundColor Cyan
Write-Host "Si no viste eventos, puede ser porque:" -ForegroundColor Yellow
Write-Host "1. No hay mensajes nuevos en Esendex" -ForegroundColor Gray
Write-Host "2. El watcher ya detectó todos los mensajes existentes" -ForegroundColor Gray
Write-Host "3. El intervalo es de $($watcher.IntervalSeconds) segundos" -ForegroundColor Gray
Write-Host "`nPara ver más actividad, puedes:" -ForegroundColor Yellow
Write-Host "- Esperar más tiempo" -ForegroundColor Gray
Write-Host "- Enviar un mensaje SMS a tu número de Esendex" -ForegroundColor Gray
Write-Host "- Cambiar el intervalo en appsettings.json" -ForegroundColor Gray
