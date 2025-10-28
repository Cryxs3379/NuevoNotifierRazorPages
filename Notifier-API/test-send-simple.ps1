# Script simple de prueba para envío de SMS
Write-Host "=== Prueba Simple de Envío de SMS ===" -ForegroundColor Cyan

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

# Test 1: SMS básico
Write-Host "`n--- Test 1: SMS Básico ---" -ForegroundColor Yellow
$body1 = @{
    to = "+34600123456"
    message = "Hola! Este es un mensaje de prueba desde la API."
} | ConvertTo-Json

try {
    $response1 = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" -Method POST -Body $body1 -ContentType "application/json"
    Write-Host "✅ SMS enviado exitosamente!" -ForegroundColor Green
    Write-Host "ID: $($response1.id)" -ForegroundColor Green
    Write-Host "To: $($response1.to)" -ForegroundColor Green
    Write-Host "Submitted: $($response1.submittedUtc)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: SMS con accountRef
Write-Host "`n--- Test 2: SMS con AccountRef ---" -ForegroundColor Yellow
$body2 = @{
    to = "+34600123457"
    message = "Mensaje con accountRef"
    accountRef = "TEST-ACCOUNT"
} | ConvertTo-Json

try {
    $response2 = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" -Method POST -Body $body2 -ContentType "application/json"
    Write-Host "✅ SMS con accountRef enviado!" -ForegroundColor Green
    Write-Host "ID: $($response2.id)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: SMS con formato inválido (debería fallar)
Write-Host "`n--- Test 3: SMS con Formato Inválido (debería fallar) ---" -ForegroundColor Yellow
$body3 = @{
    to = "600123456"  # Sin + y código país
    message = "Este debería fallar por formato"
} | ConvertTo-Json

try {
    $response3 = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" -Method POST -Body $body3 -ContentType "application/json"
    Write-Host "⚠️  Inesperado: SMS se envió cuando debería haber fallado" -ForegroundColor Yellow
}
catch {
    Write-Host "✅ Correcto: Error esperado - $($_.Exception.Message)" -ForegroundColor Green
}

# Test 4: SMS con mensaje vacío (debería fallar)
Write-Host "`n--- Test 4: SMS con Mensaje Vacío (debería fallar) ---" -ForegroundColor Yellow
$body4 = @{
    to = "+34600123458"
    message = ""
} | ConvertTo-Json

try {
    $response4 = Invoke-RestMethod -Uri "http://localhost:5080/api/v1/messages/reply" -Method POST -Body $body4 -ContentType "application/json"
    Write-Host "⚠️  Inesperado: SMS se envió cuando debería haber fallado" -ForegroundColor Yellow
}
catch {
    Write-Host "✅ Correcto: Error esperado - $($_.Exception.Message)" -ForegroundColor Green
}

Write-Host "`n=== Prueba Completada ===" -ForegroundColor Cyan
Write-Host "Funcionalidades probadas:" -ForegroundColor Yellow
Write-Host "• Envío de SMS básico" -ForegroundColor Gray
Write-Host "• Envío con accountRef" -ForegroundColor Gray
Write-Host "• Validación de formato E.164" -ForegroundColor Gray
Write-Host "• Validación de mensaje requerido" -ForegroundColor Gray
Write-Host "• Servicio Mock para pruebas" -ForegroundColor Gray
