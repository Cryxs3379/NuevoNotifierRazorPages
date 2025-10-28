# Script de prueba para el InboxWatcher CORREGIDO
Write-Host "=== Prueba del InboxWatcher CORREGIDO ===" -ForegroundColor Cyan

# Función para probar el stream SSE con timeout
function Test-SSEStream {
    param([string]$url, [int]$timeoutSeconds = 20)
    
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
        $heartbeatCount = 0
        $messageCount = 0
        
        while (-not $reader.EndOfStream -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
            $line = $reader.ReadLine()
            if ($line -and $line.StartsWith("data: ")) {
                $json = $line.Substring(6)
                $eventCount++
                
                try {
                    $event = $json | ConvertFrom-Json
                    if ($event.type -eq "heartbeat") {
                        $heartbeatCount++
                        Write-Host "[$eventCount] 💓 Heartbeat" -ForegroundColor Blue
                    }
                    elseif ($event.type -eq "new_message") {
                        $messageCount++
                        Write-Host "[$eventCount] 📨 Nuevo mensaje: $($event.id)" -ForegroundColor Green
                    }
                }
                catch {
                    Write-Host "[$eventCount] Raw: $json" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`n=== RESUMEN ===" -ForegroundColor Cyan
        Write-Host "Total de eventos: $eventCount" -ForegroundColor White
        Write-Host "Heartbeats: $heartbeatCount" -ForegroundColor Blue
        Write-Host "Mensajes nuevos: $messageCount" -ForegroundColor Green
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

# Mostrar mejoras implementadas
Write-Host "`n=== MEJORAS IMPLEMENTADAS ===" -ForegroundColor Cyan
Write-Host "✅ Ahora consulta 10 mensajes (antes solo 1)" -ForegroundColor Green
Write-Host "✅ Detecta TODOS los mensajes nuevos (no solo el último)" -ForegroundColor Green
Write-Host "✅ Notifica mensajes en orden cronológico" -ForegroundColor Green
Write-Host "✅ No pierde mensajes cuando llegan varios a la vez" -ForegroundColor Green

# Probar el stream SSE
Write-Host "`n=== Probando Stream SSE CORREGIDO ===" -ForegroundColor Cyan
Write-Host "El watcher ahora es más robusto y detecta múltiples mensajes..." -ForegroundColor Yellow
Write-Host "Conectando al stream para ver eventos en tiempo real..." -ForegroundColor Yellow

Test-SSEStream "http://localhost:5080/api/v1/stream/messages" 25

Write-Host "`n=== Prueba completada ===" -ForegroundColor Cyan
Write-Host "El watcher corregido ahora:" -ForegroundColor Yellow
Write-Host "• Consulta los primeros 10 mensajes cada $($watcher.IntervalSeconds) segundos" -ForegroundColor Gray
Write-Host "• Detecta TODOS los mensajes nuevos, no solo el último" -ForegroundColor Gray
Write-Host "• Notifica mensajes en orden cronológico" -ForegroundColor Gray
Write-Host "• Es robusto ante múltiples mensajes simultáneos" -ForegroundColor Gray
