# Test Esendex API Connection
Write-Host "Testing Esendex API Connection..." -ForegroundColor Cyan

$username = "esoriano@hellehollis.com"
$apiPassword = "25ff90e0c5e444908f2a"
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${apiPassword}"))

$headers = @{
    "Authorization" = "Basic $base64Auth"
    "Accept" = "application/json"
}

Write-Host "`nTrying endpoint 1: https://api.esendex.com/v1.0/inbox/messages" -ForegroundColor Yellow
try {
    $response1 = Invoke-WebRequest -Uri "https://api.esendex.com/v1.0/inbox/messages?pagesize=10" -Headers $headers -Method Get -TimeoutSec 10
    Write-Host "SUCCESS! Status: $($response1.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response1.Content)" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host "`nTrying endpoint 2: https://api.esendex.es/v1.0/inbox/messages" -ForegroundColor Yellow
try {
    $response2 = Invoke-WebRequest -Uri "https://api.esendex.es/v1.0/inbox/messages?pagesize=10" -Headers $headers -Method Get -TimeoutSec 10
    Write-Host "SUCCESS! Status: $($response2.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response2.Content)" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host "`nTrying endpoint 3: https://api.esendex.com/v1.0/messageheaders" -ForegroundColor Yellow
try {
    $response3 = Invoke-WebRequest -Uri "https://api.esendex.com/v1.0/messageheaders?count=10" -Headers $headers -Method Get -TimeoutSec 10
    Write-Host "SUCCESS! Status: $($response3.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response3.Content)" -ForegroundColor Green
} catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan

