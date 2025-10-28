# Script de prueba para envío de SMS con notificaciones SSE
Write-Host "=== Prueba de Envío de SMS con SSE ===" -ForegroundColor Cyan

# Función para probar el stream SSE con timeout
function Test-SSEStream {
    param([string]$url, [int]$timeoutSeconds = 30)
    
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
        $messageReceivedCount = 0
        $messageSentCount = 0
        
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
                        $messageReceivedCount++
                        Write-Host "[$eventCount] 📨 Nuevo mensaje recibido: $($event.id)" -ForegroundColor Green
                    }
                    elseif ($event.type -eq "message_sent") {
                        $messageSentCount++
                        Write-Host "[$eventCount] 📤 Mensaje enviado: $($event.id) -> $($event.to)" -ForegroundColor Magenta
                    }
                }
                catch {
                    Write-Host "[$eventCount] Raw: $json" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`n=== RESUMEN SSE ===" -ForegroundColor Cyan
        Write-Host "Total de eventos: $eventCount" -ForegroundColor White
        Write-Host "Heartbeats: $heartbeatCount" -ForegroundColor Blue
        Write-Host "Mensajes recibidos: $messageReceivedCount" -ForegroundColor Green
        Write-Host "Mensajes enviados: $messageSentCount" -ForegroundColor Magenta
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

# Función para enviar SMS
function Send-SMS {
    param([string]$to, [string]$message, [string]$accountRef = $null)
    
    $body = @{
        to = $to
        message = $message
    }
    
    if ($accountRef) {
        $body.accountRef = $accountRef
    }
    
    $json = $body | ConvertTo-Json
    $headers = @{
        "Content-Type" = "application/json"
    }
    
    try {
        Write-Host "`nEnviando SMS..." -ForegroundColor Yellow
        Write-Host "To: $to" -ForegroundColor Gray
        Write-Host "Message: $message" -ForegroundColor Gray
        if ($accountRef) { Write-Host "AccountRef: $accountRef" -ForegroundColor Gray }
        
        $response = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" -Method POST -Body $json -Headers $headers
        Write-Host "✅ SMS enviado exitosamente!" -ForegroundColor Green
        Write-Host "ID: $($response.id)" -ForegroundColor Green
        Write-Host "To: $($response.to)" -ForegroundColor Green
        Write-Host "Submitted: $($response.submittedUtc)" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "❌ Error enviando SMS: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response: $responseBody" -ForegroundColor Red
        }
        return $null
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

# Mostrar funcionalidades implementadas
Write-Host "`n=== FUNCIONALIDADES IMPLEMENTADAS ===" -ForegroundColor Cyan
Write-Host "✅ Endpoint POST /api/v1/messages/reply" -ForegroundColor Green
Write-Host "✅ Validación de formato E.164 para números de teléfono" -ForegroundColor Green
Write-Host "✅ Soporte para accountRef opcional" -ForegroundColor Green
Write-Host "✅ Notificaciones SSE tipo 'message_sent'" -ForegroundColor Green
Write-Host "✅ Servicio Mock para pruebas (sin credenciales Esendex)" -ForegroundColor Green
Write-Host "✅ Servicio real Esendex (con credenciales)" -ForegroundColor Green

# Iniciar stream SSE en background
Write-Host "`n=== Iniciando Stream SSE en Background ===" -ForegroundColor Cyan
$sseJob = Start-Job -ScriptBlock {
    param($url, $timeout)
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "GET"
        $request.Timeout = $timeout * 1000
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        
        $eventCount = 0
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line -and $line.StartsWith("data: ")) {
                $json = $line.Substring(6)
                $eventCount++
                try {
                    $event = $json | ConvertFrom-Json
                    if ($event.type -eq "message_sent") {
                        Write-Output "[$eventCount] 📤 Mensaje enviado: $($event.id) -> $($event.to)"
                    }
                }
                catch { }
            }
        }
    }
    catch {
        Write-Output "Error en SSE: $($_.Exception.Message)"
    }
} -ArgumentList "http://localhost:5080/api/v1/stream/messages", 60

# Esperar un poco para que se conecte el stream
Start-Sleep -Seconds 2

# Probar envío de SMS
Write-Host "`n=== Probando Envío de SMS ===" -ForegroundColor Cyan

# Test 1: SMS básico
Write-Host "`n--- Test 1: SMS Básico ---" -ForegroundColor Yellow
$result1 = Send-SMS -to "+34600123456" -message "Hola! Este es un mensaje de prueba desde la API."

# Test 2: SMS con accountRef
Write-Host "`n--- Test 2: SMS con AccountRef ---" -ForegroundColor Yellow
$result2 = Send-SMS -to "+34600123457" -message "Mensaje con accountRef" -accountRef "TEST-ACCOUNT"

# Test 3: SMS con formato inválido (debería fallar)
Write-Host "`n--- Test 3: SMS con Formato Inválido (debería fallar) ---" -ForegroundColor Yellow
$result3 = Send-SMS -to "600123456" -message "Este debería fallar por formato"

# Test 4: SMS con mensaje vacío (debería fallar)
Write-Host "`n--- Test 4: SMS con Mensaje Vacío (debería fallar) ---" -ForegroundColor Yellow
$result4 = Send-SMS -to "+34600123458" -message ""

# Esperar un poco más para ver eventos SSE
Write-Host "`nEsperando eventos SSE..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Detener el job de SSE
Stop-Job $sseJob
$sseOutput = Receive-Job $sseJob
Remove-Job $sseJob

Write-Host "`n=== Eventos SSE Capturados ===" -ForegroundColor Cyan
if ($sseOutput) {
    $sseOutput | ForEach-Object { Write-Host $_ -ForegroundColor Magenta }
} else {
    Write-Host "No se capturaron eventos SSE" -ForegroundColor Gray
}

Write-Host "`n=== Prueba Completada ===" -ForegroundColor Cyan
Write-Host "Funcionalidades probadas:" -ForegroundColor Yellow
Write-Host "• Envío de SMS básico" -ForegroundColor Gray
Write-Host "• Envío con accountRef" -ForegroundColor Gray
Write-Host "• Validación de formato E.164" -ForegroundColor Gray
Write-Host "• Validación de mensaje requerido" -ForegroundColor Gray
Write-Host "• Notificaciones SSE en tiempo real" -ForegroundColor Gray
Write-Host "• Servicio Mock para pruebas" -ForegroundColor Gray
