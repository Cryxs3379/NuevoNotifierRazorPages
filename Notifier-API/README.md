# Notifier API - Esendex Integration v1.0

API en .NET 8 (ASP.NET Core Minimal API) que se conecta a la API de Esendex y expone endpoints para listar mensajes entrantes con funcionalidades avanzadas de resiliencia, caching y seguridad.

## 🚀 Características

### Core
- **Integración con Esendex**: Conexión real a la API de Esendex con autenticación Basic Auth
- **Modo Mock**: Si no hay credenciales configuradas, devuelve datos de ejemplo
- **Health Check**: Endpoint para verificar el estado de la API y configuración
- **Versionado API**: Endpoints versionados (`/api/v1/...`) con compatibilidad legacy

### Resiliencia & Performance
- **Circuit Breaker**: Protección contra cascadas de fallos (configurable: 5 fallos/30s)
- **Retry Policy**: Reintentos automáticos con exponential backoff
- **Output Caching**: Cache de respuestas de 30s (configurable)
- **Timeout Management**: Timeouts configurables por operación
- **DNS Resilience**: Fallback automático a URL alternativa (España/Internacional)

### Seguridad
- **API Key Protection**: Autenticación opcional mediante header `X-API-Key`
- **CORS**: Configurado para desarrollo, validado en producción (sin wildcards)
- **Secure Logging**: Nunca registra credenciales ni cuerpos de mensajes completos
- **ProblemDetails**: Errores estandarizados con mensajes claros

### API Design
- **Paginación Mejorada**: Headers `X-Total-Count` y `Link` (rel: first, prev, next, last)
- **Swagger UI**: Documentación interactiva (solo Development)
- **Validación**: Límites configurables para page/pageSize
- **Account Reference**: Soporte para filtrar por cuenta Esendex

## 📋 Requisitos

- .NET 8 SDK
- Variables de entorno para credenciales de Esendex (opcional, sin ellas usa datos mock)

## 🔧 Instalación y Ejecución

### 1. Restaurar dependencias

```bash
dotnet restore
```

### 2. Configurar credenciales (opcional)

#### Opción A: Archivo de configuración (Recomendado para desarrollo)

Edita el archivo `appsettings.Local.json`:

```json
{
  "Esendex": {
    "Username": "tu.email@empresa.com",
    "ApiPassword": "EX1234567890abcdefghijk"
  }
}
```

✅ **Este archivo NO se sube a Git** (está en `.gitignore`)

#### Opción B: Variables de entorno

**Windows (PowerShell):**
```powershell
$env:ESENDEX_USER = "tu.email@empresa.com"
$env:ESENDEX_API_PASSWORD = "EX1234567890abcdefghijk"
```

**Linux/macOS:**
```bash
export ESENDEX_USER="tu.email@empresa.com"
export ESENDEX_API_PASSWORD="EX1234567890abcdefghijk"
```

### 3. Ejecutar la aplicación

```bash
dotnet run
```

El servidor estará disponible en: **http://localhost:5080**

## 📡 Endpoints

### Health Check

Verifica el estado de la API y si las credenciales de Esendex están configuradas.

```bash
curl http://localhost:5080/api/health
```

**Respuesta:**
```json
{
  "status": "ok",
  "esendexConfigured": true
}
```

---

### 📨 Listar Mensajes Entrantes (V1)

**Endpoint principal recomendado**

```bash
curl "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=10"
```

**Parámetros:**
- `direction` (requerido): Debe ser "inbound"
- `page` (opcional, default: 1): Número de página (1-indexed)
- `pageSize` (opcional, default: 50): Tamaño de página (min: 1, max: 200)
- `accountRef` (opcional): Filtrar por Account Reference de Esendex

**Headers de Respuesta:**
```
X-Total-Count: 123
Link: <http://localhost:5080/api/v1/messages?page=1&pageSize=10>; rel="first", 
      <http://localhost:5080/api/v1/messages?page=2&pageSize=10>; rel="next", 
      <http://localhost:5080/api/v1/messages?page=13&pageSize=10>; rel="last"
Cache-Control: public, max-age=30
```

**Respuesta:**
```json
{
  "items": [
    {
      "id": "789151cb-884a-4e33-aa48-436191fe2860",
      "from": "+34607889376",
      "to": "+34987654321",
      "message": "Hola buenas esto es una prueba para ver si func...",
      "receivedUtc": "2025-10-01T09:34:42.71Z"
    }
  ],
  "page": 1,
  "pageSize": 10,
  "total": 123
}
```

---

### 📨 Listar Mensajes (Legacy)

**Endpoint de compatibilidad** - Se recomienda usar `/api/v1/messages`

```bash
curl "http://localhost:5080/api/messages?direction=inbound&page=1&pageSize=10"
```

Mismos parámetros y respuesta que v1.

---

### 🔐 Con API Key (si está habilitada)

```bash
curl -H "X-API-Key: tu_api_key_aqui" \
  "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=10"
```

---

### 🔍 Filtrar por Account Reference

Si tienes múltiples cuentas Esendex:

```bash
curl "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=10&accountRef=EX0375657"
```

---

## 📚 Swagger UI (Solo Development)

Cuando ejecutas en modo Development, puedes acceder a la documentación interactiva:

**URL:** http://localhost:5080/swagger

Desde ahí puedes:
- Ver todos los endpoints disponibles
- Probar llamadas directamente
- Ver ejemplos de request/response
- Configurar API Key si está habilitada

---

## ⚙️ Configuración

### appsettings.json

```json
{
  "Esendex": {
    "BaseUrl": "https://api.esendex.com/v1.0/",
    "AlternativeBaseUrl": "https://api.esendex.es/v1.0/",
    "PreferredFormat": "xml",
    "TimeoutSeconds": 10,
    "RetryCount": 2,
    "RetryDelayMilliseconds": 1000,
    "CircuitBreakerFailureThreshold": 5,
    "CircuitBreakerSamplingDuration": 30,
    "CircuitBreakerBreakDuration": 30,
    "MinPageSize": 1,
    "MaxPageSize": 200
  },
  "Cors": {
    "AllowedOrigins": ["http://localhost:5173"]
  },
  "ApiKey": {
    "Enabled": false,
    "Value": ""
  },
  "OutputCache": {
    "DefaultExpirationSeconds": 30
  }
}
```

**Parámetros configurables:**

#### Esendex
- `BaseUrl`: URL principal de la API (internacional o regional)
- `AlternativeBaseUrl`: URL de fallback si la principal falla
- `PreferredFormat`: "xml" o "json" (Esendex devuelve XML por defecto)
- `TimeoutSeconds`: Timeout de llamadas HTTP
- `RetryCount`: Número de reintentos
- `RetryDelayMilliseconds`: Delay base para exponential backoff
- `CircuitBreakerFailureThreshold`: Fallos antes de abrir el circuit breaker
- `CircuitBreakerSamplingDuration`: Ventana de tiempo para contar fallos (segundos)
- `CircuitBreakerBreakDuration`: Tiempo que el circuit breaker permanece abierto (segundos)
- `MinPageSize` / `MaxPageSize`: Límites de paginación

#### CORS
- `AllowedOrigins`: Lista de orígenes permitidos (no usar wildcards en producción)

#### API Key
- `Enabled`: Activar/desactivar protección por API Key
- `Value`: El API Key válido (usar secretos en producción)

#### Output Cache
- `DefaultExpirationSeconds`: Duración del cache de respuestas

---

## 🔄 Estrategia de Resiliencia

### Circuit Breaker
Si Esendex falla repetidamente, el circuit breaker se abre temporalmente para:
- Evitar sobrecarga del servicio externo
- Responder rápidamente con error 503 sin intentar llamadas
- Cerrar automáticamente después del tiempo configurado

**Respuesta cuando está abierto:**
```json
{
  "status": 503,
  "title": "Service Temporarily Unavailable",
  "detail": "The Esendex service is temporarily unavailable due to repeated errors. Please try again later."
}
```

### Retry Policy
Reintentos automáticos con exponential backoff:
- 1er reintento: 1 segundo
- 2do reintento: 2 segundos
- Solo en errores transitorios (timeout, 5xx, etc.)

### DNS Fallback
Si `BaseUrl` falla por problemas de DNS o conectividad, intenta automáticamente con `AlternativeBaseUrl`:
- Útil para cuentas regionales (.com / .es)
- Registra en logs cuál URL funcionó

---

## 🔐 Seguridad

### Activar API Key Protection

1. **Configurar en appsettings.json:**
```json
{
  "ApiKey": {
    "Enabled": true,
    "Value": "mi-api-key-secreta-123"
  }
}
```

2. **Incluir en requests:**
```bash
curl -H "X-API-Key: mi-api-key-secreta-123" \
  "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=10"
```

3. **Swagger UI:**
   - Haz clic en "Authorize"
   - Ingresa tu API Key
   - Todas las requests incluirán el header automáticamente

### Recomendaciones para Producción

1. **Secretos:**
   - Usar Azure Key Vault, AWS Secrets Manager o HashiCorp Vault
   - NO usar variables de entorno en producción
   - NO hacer commit de credenciales

2. **CORS:**
   - Configurar solo dominios específicos
   - NO usar wildcards (`*`)
   - Ejemplo:
     ```json
     "AllowedOrigins": ["https://app.miempresa.com"]
     ```

3. **HTTPS:**
   - Configurar certificados SSL/TLS
   - Forzar HTTPS en producción

4. **Rate Limiting:**
   - Implementar límites por IP/API Key
   - Proteger contra abusos

5. **Logging y Monitoring:**
   - Application Insights, Serilog, o ELK Stack
   - Alertas para errores 401/403/502/503
   - **Nunca loguear**: credenciales, API Keys, cuerpos completos de mensajes

---

## 🧪 Testing Manual

### 1. Health Check
```bash
curl http://localhost:5080/api/health
```

### 2. Mensajes Mock (sin credenciales)
```bash
curl "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"
```

### 3. Mensajes Reales (con credenciales)
Configura credenciales y ejecuta:
```bash
curl "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"
```

### 4. Verificar Headers de Paginación
```bash
curl -i "http://localhost:5080/api/v1/messages?direction=inbound&page=2&pageSize=10"
```
Busca headers `X-Total-Count` y `Link`.

### 5. Probar Cache
```bash
# Primera llamada (sin cache)
curl -i "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"

# Segunda llamada (desde cache - más rápida)
curl -i "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"
```
Verifica header `Cache-Control`.

### 6. Probar API Key (si está habilitada)
```bash
# Sin API Key (debe fallar con 401)
curl "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"

# Con API Key (debe funcionar)
curl -H "X-API-Key: tu-api-key" \
  "http://localhost:5080/api/v1/messages?direction=inbound&page=1&pageSize=5"
```

---

## 🐛 Troubleshooting

### Error 401/403 - Authentication Failed
- Verifica que las credenciales sean correctas
- El API Password es diferente de tu contraseña web
- Obtén el API Password desde: Settings → API Access en el portal de Esendex

### Error 502 - Service Unavailable
- Esendex no está disponible o hay problemas de red
- Verifica conectividad a internet
- Revisa logs para ver qué URL falló

### Error 503 - Circuit Breaker Open
- El circuit breaker está abierto por múltiples fallos
- Espera 30 segundos (configurable) y reinténtalo
- Revisa logs para identificar el problema raíz

### esendexConfigured: false
- Las credenciales no están cargadas
- Verifica variables de entorno o `appsettings.Local.json`
- Reinicia la aplicación después de configurar

### Cache no funciona
- Verifica header `Cache-Control` en la respuesta
- El cache varía por query params (page, pageSize, direction, accountRef)
- En Development, el cache puede estar deshabilitado

---

## 📝 Estructura del Proyecto

```
Notifier-API/
├── Program.cs                      # Configuración Minimal API + DI + Middleware
├── Notifier-API.csproj             # Proyecto .NET 8
├── appsettings.json                # Configuración general
├── appsettings.Local.json          # Credenciales locales (no en Git)
├── README.md                       # Este archivo
├── Configuration/
│   ├── EsendexSettings.cs          # Settings de Esendex
│   ├── ApiKeySettings.cs           # Settings de API Key
│   └── OutputCacheSettings.cs      # Settings de Output Cache
├── Models/
│   ├── MessageDto.cs               # DTO para mensajes
│   ├── MessagesResponse.cs         # Respuesta paginada
│   └── HealthResponse.cs           # Respuesta health check
├── Services/
│   ├── IInboxService.cs            # Interfaz del servicio
│   ├── EsendexInboxService.cs      # Implementación real (Esendex)
│   └── MockInboxService.cs         # Implementación mock
├── Middleware/
│   └── ApiKeyMiddleware.cs         # Middleware de autenticación
└── Helpers/
    └── PaginationHelper.cs         # Helpers para paginación
```

---

## 📦 Dependencias

- **Microsoft.AspNetCore.OpenApi** (8.0.0): Soporte OpenAPI
- **Swashbuckle.AspNetCore** (6.5.0): Swagger UI
- **Polly** (8.2.0): Políticas de resiliencia
- **Polly.Extensions.Http** (3.0.0): Integración HTTP con Polly
- **Microsoft.Extensions.Http.Polly** (8.0.0): Circuit Breaker y Retry

---

## 📄 Licencia

Este proyecto es código de ejemplo para integración con Esendex.

---

## 🤝 Contribuir

Para mejoras o reportar issues, contacta con el equipo de desarrollo.

---

**Nota**: Recuerda nunca compartir tus credenciales de API. Mantenlas seguras y usa secret stores en producción.

Ver también: `PRODUCTION-GUIDE.md` para guía completa de despliegue en producción.
