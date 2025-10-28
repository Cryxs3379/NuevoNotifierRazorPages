# Changelog

## [1.0.0] - 2025-10-01

### ✨ Nuevas Características

#### Resiliencia & Performance
- **Circuit Breaker Polly**: Protección contra cascadas de fallos (5 fallos/30s → break 30s)
- **Retry Policy con Exponential Backoff**: Reintentos automáticos configurables
- **Output Caching**: Cache de respuestas de 30s con variación por query params
- **DNS Resilience**: Fallback automático a `AlternativeBaseUrl` si falla la principal
- **Timeout Management**: Timeouts configurables por operación

#### API Design
- **Versionado v1**: Endpoints bajo `/api/v1/...` con compatibilidad legacy
- **Swagger/OpenAPI**: Documentación interactiva en Development
- **Headers de Paginación**: `X-Total-Count` y `Link` (rel: first, prev, next, last)
- **Validación Mejorada**: Límites configurables para `pageSize` (min/max desde config)
- **Account Reference**: Parámetro opcional `accountRef` para filtrar por cuenta

#### Seguridad
- **API Key Middleware**: Autenticación opcional mediante header `X-API-Key`
- **CORS Mejorado**: Validación estricta en producción (no wildcards)
- **Secure Logging**: Nunca registra credenciales ni cuerpos completos de mensajes
- **ProblemDetails**: Errores estandarizados con mensajes claros

#### Esendex
- **Preferred Format**: Negociación de contenido (XML/JSON) configurable
- **Multi-endpoint Fallback**: Prueba 3 endpoints automáticamente
- **URL Sanitization**: Logs seguros sin credenciales en URLs
- **Better Error Messages**: Mensajes claros cuando falla autenticación

### 🔧 Mejoras Técnicas
- **Named HttpClient "Esendex"**: Centralizado con Polly policies
- **Dependency Injection mejorada**: Configuración modular de settings
- **CancellationToken**: Soporte completo en toda la cadena async
- **Unit Tests**: Tests para parsing XML, paginación y construcción de URLs

### 📚 Documentación
- **README completo**: Guía detallada con todos los endpoints y configuraciones
- **CHANGELOG**: Este archivo
- **Tests**: Ejemplos de uso y casos de prueba
- **Swagger**: Documentación interactiva generada automáticamente

### 🔄 Breaking Changes
Ninguno - mantiene compatibilidad con endpoints legacy.

### ⬆️ Dependencias
- Swashbuckle.AspNetCore 6.5.0
- Microsoft.Extensions.Http.Polly 8.0.0

---

## [0.1.0] - 2025-10-01 (Inicial)

### Características Iniciales
- Integración básica con Esendex
- Endpoint `/api/messages` para mensajes entrantes
- Modo mock sin credenciales
- Health check endpoint
- Configuración desde appsettings.json y variables de entorno
- CORS básico
- Basic Auth con Esendex
- Parser XML para respuestas de Esendex
- Retry policy básico
- README con instrucciones de uso

