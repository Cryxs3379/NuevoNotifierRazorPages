# Script para probar el envío REAL de SMS con Esendex
# IMPORTANTE: Siempre usa EsendexSendService (nunca mock)

Write-Host "=== PRUEBA DE ENVÍO REAL DE SMS (SIEMPRE REAL) ===" -ForegroundColor Cyan

# Verificar que la API esté funcionando
Write-Host "`n1. Verificando estado de la API..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5080/api/health" -Method GET
    Write-Host "✅ API Status: $($health.status)" -ForegroundColor Green
    Write-Host "✅ Esendex Configured: $($health.esendexConfigured)" -ForegroundColor Green
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
        Write-Host "`n📤 Enviando SMS REAL a $to..." -ForegroundColor Yellow
        $response = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" `
            -Method POST `
            -ContentType "application/json" `
            -Body ($body | ConvertTo-Json) `
            -ErrorAction Stop
        
        Write-Host "✅ SMS enviado exitosamente a Esendex!" -ForegroundColor Green
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
Write-Host "`n2. Probando envío REAL de SMS..." -ForegroundColor Yellow
Write-Host "⚠️  IMPORTANTE: Siempre se envía a Esendex (nunca simulado)" -ForegroundColor Yellow

# Test 1: SMS básico
Write-Host "`n--- Test 1: SMS Básico ---" -ForegroundColor Cyan
$result1 = Send-SMS -to "+34600123456" -message "Hola! Este es un mensaje REAL desde Notifier API."

if ($result1) {
    Write-Host "✅ Test 1 PASADO - SMS enviado a Esendex" -ForegroundColor Green
} else {
    Write-Host "❌ Test 1 FALLÓ - Error en Esendex" -ForegroundColor Red
}

# Test 2: SMS con AccountRef
Write-Host "`n--- Test 2: SMS con AccountRef ---" -ForegroundColor Cyan
$result2 = Send-SMS -to "+34600123457" -message "Mensaje REAL con accountRef específico." -accountRef "EX000000"

if ($result2) {
    Write-Host "✅ Test 2 PASADO - SMS enviado a Esendex" -ForegroundColor Green
} else {
    Write-Host "❌ Test 2 FALLÓ - Error en Esendex" -ForegroundColor Red
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
Write-Host "🔴 TODOS los envíos van a Esendex (nunca simulados)" -ForegroundColor Red
Write-Host "📋 Si ves errores 401/403, revisa las credenciales en appsettings.Local.json" -ForegroundColor Yellow
Write-Host "📋 Si ves errores 400, revisa el formato del número de teléfono" -ForegroundColor Yellow
Write-Host "📋 Si ves errores 500, revisa los logs de la API" -ForegroundColor Yellow

Write-Host "`n📝 Para ver los logs de la API, ejecuta: dotnet run" -ForegroundColor Green
Write-Host "📝 Para ver el Swagger UI: http://localhost:5080/swagger" -ForegroundColor Green
Write-Host "📝 Para configurar credenciales: Edita appsettings.Local.json" -ForegroundColor Green