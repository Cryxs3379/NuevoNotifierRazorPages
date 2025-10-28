# Script de prueba para Server-Sent Events
Write-Host "=== Prueba de Server-Sent Events ===" -ForegroundColor Cyan

# Función para probar el stream SSE
function Test-SSEStream {
    param([string]$url)
    
    Write-Host "`nConectando al stream SSE: $url" -ForegroundColor Yellow
    Write-Host "Presiona Ctrl+C para detener el stream" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Gray
    
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "GET"
        $request.Timeout = 30000
        
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line -and $line.StartsWith("data: ")) {
                $json = $line.Substring(6)
                Write-Host "Evento recibido: $json" -ForegroundColor Green
            }
        }
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

# Función para disparar eventos llamando al endpoint de mensajes
function Trigger-MessageEvent {
    Write-Host "`nDisparando evento llamando a /api/v1/messages..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"
        Write-Host "Mensajes obtenidos: $($response.items.Count)" -ForegroundColor Green
        if ($response.items.Count -gt 0) {
            Write-Host "Último mensaje ID: $($response.items[0].id)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error obteniendo mensajes: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Verificar si la API está funcionando
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

# Iniciar el stream SSE en un job en segundo plano
Write-Host "`nIniciando stream SSE en segundo plano..." -ForegroundColor Yellow
$sseJob = Start-Job -ScriptBlock {
    param($url)
    $request = [System.Net.WebRequest]::Create($url)
    $request.Method = "GET"
    $request.Timeout = 30000
    
    $response = $request.GetResponse()
    $stream = $response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ($line -and $line.StartsWith("data: ")) {
            $json = $line.Substring(6)
            Write-Output "SSE: $json"
        }
    }
} -ArgumentList "http://localhost:5080/api/v1/stream/messages"

# Esperar un poco y luego disparar eventos
Start-Sleep -Seconds 3
Write-Host "`nDisparando eventos cada 10 segundos..." -ForegroundColor Yellow
Write-Host "Presiona Ctrl+C para detener" -ForegroundColor Yellow

$count = 0
while ($true) {
    $count++
    Write-Host "`n--- Disparo #$count ---" -ForegroundColor Cyan
    Trigger-MessageEvent
    
    # Verificar si hay eventos en el job
    $events = Receive-Job -Job $sseJob -ErrorAction SilentlyContinue
    if ($events) {
        foreach ($event in $events) {
            Write-Host $event -ForegroundColor Green
        }
    }
    
    Start-Sleep -Seconds 10
}
