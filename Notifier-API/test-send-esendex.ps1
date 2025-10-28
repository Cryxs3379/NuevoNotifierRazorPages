# Script para probar el envío REAL de SMS con Esendex
# Configuración: Usa servicio real si hay credenciales, mock si no

Write-Host "=== PRUEBA DE ENVÍO DE SMS CON ESENDEX ===" -ForegroundColor Cyan

# Verificar que la API esté funcionando
Write-Host "`n1. Verificando estado de la API..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5080/api/health" -Method GET
    Write-Host "✅ API Status: $($health.status)" -ForegroundColor Green
    Write-Host "✅ Esendex Configured: $($health.esendexConfigured)" -ForegroundColor Green
    
    if ($health.esendexConfigured) {
        Write-Host "🔴 MODO REAL: Se enviará a Esendex" -ForegroundColor Red
    } else {
        Write-Host "🟡 MODO MOCK: Se simulará el envío" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error conectando a la API: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Asegúrate de que la API esté ejecutándose en http://localhost:5080" -ForegroundColor Yellow
    exit 1
}

# Función para enviar SMS
function Send-SMS {
    param(
        [string]$to,
        [string]$message,
        [string]$accountRef = $null
    )
    
    $body = @{
        to = $to
        message = $message
    }
    
    if ($accountRef) {
        $body.accountRef = $accountRef
    }

    try {
        Write-Host "`n📤 Enviando SMS a $to..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" `
            -Method POST `
            -ContentType "application/json" `
            -Body ($body | ConvertTo-Json) `
            -ErrorAction Stop
        
        Write-Host "✅ SMS procesado exitosamente!" -ForegroundColor Green
        Write-Host "   ID: $($response.id)" -ForegroundColor Green
        Write-Host "   To: $($response.to)" -ForegroundColor Green
        Write-Host "   Submitted: $($response.submittedUtc)" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Host "❌ Error enviando SMS: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-Host "   Status Code: $statusCode" -ForegroundColor Red
            
            # Interpretar códigos de error comunes
            switch ($statusCode) {
                401 { Write-Host "   → Error de autenticación: Revisa Username/ApiPassword" -ForegroundColor Yellow }
                403 { Write-Host "   → Error de autorización: Revisa AccountReference" -ForegroundColor Yellow }
                400 { Write-Host "   → Error de validación: Revisa formato del número" -ForegroundColor Yellow }
                500 { Write-Host "   → Error interno: Revisa logs de la API" -ForegroundColor Yellow }
            }
        }
        return $null
    }
}

# Pruebas
Write-Host "`n2. Probando envío de SMS..." -ForegroundColor Yellow

# Test 1: SMS básico
Write-Host "`n--- Test 1: SMS Básico ---" -ForegroundColor Cyan
$result1 = Send-SMS -to "+34600123456" -message "Hola! Este es un mensaje desde Notifier API."

if ($result1) {
    Write-Host "✅ Test 1 PASADO" -ForegroundColor Green
} else {
    Write-Host "❌ Test 1 FALLÓ" -ForegroundColor Red
}

# Test 2: SMS con AccountRef
Write-Host "`n--- Test 2: SMS con AccountRef ---" -ForegroundColor Cyan
$result2 = Send-SMS -to "+34600123457" -message "Mensaje con accountRef específico." -accountRef "EX0375657"

if ($result2) {
    Write-Host "✅ Test 2 PASADO" -ForegroundColor Green
} else {
    Write-Host "❌ Test 2 FALLÓ" -ForegroundColor Red
}

# Test 3: Validación de formato (debería fallar)
Write-Host "`n--- Test 3: Validación de Formato (debería fallar) ---" -ForegroundColor Cyan
try {
    $result3 = Send-SMS -to "600123456" -message "Este debería fallar por formato."
    if ($result3) {
        Write-Host "❌ Test 3 FALLÓ - Debería haber fallado por formato inválido" -ForegroundColor Red
    } else {
        Write-Host "✅ Test 3 PASADO - Falló correctamente por formato inválido" -ForegroundColor Green
    }
} catch {
    Write-Host "✅ Test 3 PASADO - Falló correctamente por formato inválido" -ForegroundColor Green
}

Write-Host "`n=== RESUMEN DE PRUEBAS ===" -ForegroundColor Cyan
Write-Host "📋 Configuración actual:" -ForegroundColor Yellow
Write-Host "   - BaseUrl: https://api.esendex.com/" -ForegroundColor Gray
Write-Host "   - Username: TU_USUARIO_DE_LOGIN" -ForegroundColor Gray
Write-Host "   - ApiPassword: 25ff90e0c5e444908f2a" -ForegroundColor Gray
Write-Host "   - AccountReference: EX0375657" -ForegroundColor Gray

Write-Host "`n📋 Para usar envío REAL:" -ForegroundColor Yellow
Write-Host "   1. Reemplaza 'TU_USUARIO_DE_LOGIN' por tu email real de Esendex" -ForegroundColor Yellow
Write-Host "   2. Verifica que ApiPassword y AccountReference sean correctos" -ForegroundColor Yellow
Write-Host "   3. Reinicia la API: dotnet run" -ForegroundColor Yellow

Write-Host "`n📝 Para ver los logs: dotnet run" -ForegroundColor Green
Write-Host "📝 Para ver Swagger: http://localhost:5080/swagger" -ForegroundColor Green
