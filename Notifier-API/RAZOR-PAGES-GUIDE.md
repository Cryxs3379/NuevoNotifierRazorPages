# Notifier - Guía de Razor Pages

## 📋 Descripción

Aplicación web integrada con **Razor Pages** para gestionar mensajes SMS (Esendex) y consultar llamadas perdidas. Reemplaza completamente el frontend React anterior.

## 🏗️ Arquitectura

```
Notifier-API/
├── Pages/                          # Razor Pages (UI)
│   ├── Index.cshtml               # Página principal
│   ├── Messages/
│   │   ├── Index.cshtml           # Ver mensajes (inbound/outbound)
│   │   └── Reply.cshtml           # Enviar mensajes SMS
│   └── Calls/
│       └── Index.cshtml           # Ver llamadas perdidas
├── Services/                       # Servicios de negocio
│   ├── EsendexInboxService.cs    # Servicio de mensajes Esendex
│   ├── EsendexSendService.cs     # Servicio de envío Esendex
│   └── MissedCallsService.cs     # Servicio de llamadas perdidas
├── Models/                         # DTOs
├── wwwroot/                        # Archivos estáticos
│   └── css/
│       └── site.css               # Estilos personalizados
└── Program.cs                      # Configuración de la aplicación
```

## 🚀 Inicio Rápido

### 1. Configurar las APIs

**API de Mensajes (Notifier-API):**
- Puerto: `5080`
- Ya está configurada con Razor Pages integradas

**API de Llamadas (Notifier-APiCalls):**
- Puerto: `5000` (por defecto)
- Debe estar ejecutándose para ver llamadas perdidas

### 2. Configurar `appsettings.json`

```json
{
  "Esendex": {
    "BaseUrl": "https://api.esendex.com/v1.0/",
    "Username": "tu.email@empresa.com",
    "ApiPassword": "EX1234567890abcdefghijk",
    "AccountReference": "EX0375657"
  },
  "MissedCallsAPI": {
    "BaseUrl": "http://localhost:5000"
  }
}
```

### 3. Ejecutar la Aplicación

**Opción A: Desde Visual Studio**
1. Abre el proyecto `Notifier-API`
2. Presiona `F5` o haz clic en "Run"

**Opción B: Desde terminal**
```bash
cd Notifier-API
dotnet run
```

### 4. Acceder a la Aplicación

Abre tu navegador en: **http://localhost:5080**

## 📱 Funcionalidades

### 1. Página Principal (`/`)
- Dashboard con tarjetas de navegación
- Estado del sistema Esendex
- Acceso rápido a todas las funciones

### 2. Mensajes SMS (`/Messages/Index`)

**Funcionalidades:**
- ✅ Ver mensajes entrantes (inbound)
- ✅ Ver mensajes enviados (outbound)
- ✅ Paginación configurable (10, 25, 50, 100 mensajes)
- ✅ Filtrar por Account Reference
- ✅ Responder mensajes directamente
- ✅ Mostrar fecha/hora relativa (ej: "Hace 5 min")
- ✅ Copiar IDs de mensajes

**Filtros disponibles:**
- Dirección: Entrantes / Enviados
- Mensajes por página: 10 / 25 / 50 / 100
- Account Reference (opcional)

### 3. Enviar Mensajes (`/Messages/Reply`)

**Funcionalidades:**
- ✅ Enviar SMS a cualquier número
- ✅ Validación de formato E.164 (+34600123456)
- ✅ Contador de caracteres y SMS
- ✅ Pre-llenado desde "Responder" en tabla de mensajes
- ✅ Account Reference opcional

**Validaciones:**
- Formato de número: `^\+\d{6,15}$`
- Longitud de mensaje: 1-612 caracteres
- Cálculo automático de número de SMS (160 caracteres por SMS)

### 4. Llamadas Perdidas (`/Calls/Index`)

**Funcionalidades:**
- ✅ Ver llamadas perdidas desde la base de datos
- ✅ Estadísticas en tiempo real (Total, Hoy, Esta Semana)
- ✅ Última llamada perdida
- ✅ Enviar SMS directo desde una llamada
- ✅ Indicador de estado de la API

**Estadísticas:**
- Total de llamadas perdidas
- Llamadas perdidas hoy
- Llamadas perdidas esta semana
- Hora de última llamada

## 🎨 Diseño

**Framework CSS:** Bootstrap 5.3.2 (via CDN)
**Iconos:** Bootstrap Icons 1.11.1

**Características visuales:**
- 🎨 Diseño moderno y responsivo
- 📱 Mobile-friendly
- 🌈 Colores temáticos por sección:
  - Mensajes: Azul (primary)
  - Enviar: Verde (success)
  - Llamadas: Rojo (danger)
- ✨ Efectos hover en tarjetas
- 📊 Tablas con striped rows
- 🔔 Alertas con iconos

## 🔧 Configuración Avanzada

### CORS (Solo APIs)

Las Razor Pages no necesitan CORS, pero las APIs mantienen la configuración para consumo externo:

```json
{
  "Cors": {
    "AllowedOrigins": ["http://localhost:5173"]
  }
}
```

### API Key (Opcional)

Habilitar protección por API Key para endpoints de API:

```json
{
  "ApiKey": {
    "Enabled": true,
    "Value": "mi-api-key-secreta-123"
  }
}
```

**Nota:** Las Razor Pages NO requieren API Key, solo los endpoints `/api/*`

### Output Cache

Cache de respuestas de API:

```json
{
  "OutputCache": {
    "DefaultExpirationSeconds": 30
  }
}
```

### Watcher (SSE)

Monitoreo en tiempo real de mensajes nuevos:

```json
{
  "Watcher": {
    "Enabled": true,
    "IntervalSeconds": 5,
    "AccountRef": ""
  }
}
```

## 🔍 Endpoints de API (Backend)

Las Razor Pages consumen estos endpoints internamente:

### Mensajes
- `GET /api/v1/messages?direction=inbound&page=1&pageSize=25`
- `POST /api/v1/messages/reply`
- `GET /api/v1/stream/messages` (SSE)

### Health
- `GET /api/health`

### Llamadas (API Externa - Notifier-APiCalls)
- `GET /api/MissedCalls?limit=100`
- `GET /api/MissedCalls/stats`
- `GET /api/MissedCalls/test`

## 🛠️ Desarrollo

### Estructura de archivos Razor Page

Cada página Razor consiste en 2 archivos:

1. **`.cshtml`** - Vista (HTML + Razor syntax)
2. **`.cshtml.cs`** - Code-behind (PageModel)

**Ejemplo:**
```
Pages/Messages/Index.cshtml      ← Vista
Pages/Messages/Index.cshtml.cs   ← Lógica
```

### Agregar una nueva página

1. Crear `.cshtml` y `.cshtml.cs` en `Pages/`
2. La URL será automáticamente `/NombreDePagina`
3. Para rutas anidadas: `Pages/Seccion/Pagina.cshtml` → `/Seccion/Pagina`

### Servicios disponibles por DI

- `IInboxService` - Mensajes Esendex
- `ISendService` - Envío de SMS
- `IMissedCallsService` - Llamadas perdidas
- `EsendexSettings` - Configuración Esendex
- `ILogger<T>` - Logging

## 🧪 Testing

### Probar Mensajes (Mock)

Si no tienes credenciales Esendex, el sistema usa datos mock automáticamente:

```bash
# Verificar estado
curl http://localhost:5080/api/health

# Debería devolver:
{
  "status": "ok",
  "esendexConfigured": false  # ← Mock mode
}
```

### Probar con credenciales reales

1. Configurar `appsettings.json` con credenciales Esendex
2. Reiniciar aplicación
3. Verificar: `http://localhost:5080/api/health` → `esendexConfigured: true`

### Probar Llamadas Perdidas

1. Ejecutar `Notifier-APiCalls` en puerto 5000
2. Verificar conexión: `http://localhost:5000/api/MissedCalls/test`
3. Acceder a: `http://localhost:5080/Calls/Index`

## 📝 Logs

Los logs se muestran en la consola durante el desarrollo:

```
info: Notifier API starting...
info: Environment: Development
info: Esendex credentials configured: True
info: API Key protection: False
info: Razor Pages UI: http://localhost:5080
info: Swagger UI: http://localhost:5080/swagger
```

## 🚨 Troubleshooting

### Error: "No se puede conectar con la API de llamadas perdidas"

**Solución:**
1. Verifica que `Notifier-APiCalls` esté ejecutándose
2. Verifica el puerto en `appsettings.json` → `MissedCallsAPI:BaseUrl`
3. Prueba manualmente: `http://localhost:5000/api/MissedCalls/test`

### Error: "Error de autenticación con Esendex"

**Solución:**
1. Verifica las credenciales en `appsettings.json`
2. El `ApiPassword` NO es tu contraseña web, se obtiene desde el portal Esendex
3. Verifica que `AccountReference` sea correcto

### Error: "The page is not responding"

**Solución:**
1. Verifica que el puerto 5080 esté libre
2. Ejecuta: `netstat -ano | findstr :5080`
3. Si está ocupado, cambia el puerto en `Program.cs`:
   ```csharp
   app.Run("http://localhost:NUEVO_PUERTO");
   ```

### Los estilos no se cargan

**Solución:**
1. Verifica que `app.UseStaticFiles()` esté en `Program.cs`
2. Verifica que existe `wwwroot/css/site.css`
3. Limpia y reconstruye: `dotnet clean && dotnet build`

## 📦 Dependencias

Todas las dependencias ya están configuradas en `Notifier-API.csproj`:

- **Microsoft.AspNetCore.OpenApi** (8.0.0)
- **Swashbuckle.AspNetCore** (6.5.0)
- **Polly** (8.2.0)
- **Polly.Extensions.Http** (3.0.0)
- **System.ServiceModel.Syndication** (8.0.0)
- **Microsoft.Extensions.Http.Polly** (8.0.0)

No se requieren dependencias adicionales para Razor Pages (incluido en .NET 8).

## 🔄 Migración desde React

### Lo que se eliminó:
- ❌ Notifier-Frontend (carpeta completa)
- ❌ Node.js y npm
- ❌ React, Vite, TailwindCSS
- ❌ TypeScript
- ❌ Zustand, React Query

### Lo que se agregó:
- ✅ Razor Pages integradas en Notifier-API
- ✅ Bootstrap 5 (via CDN)
- ✅ Sin compilación de frontend
- ✅ Todo en un solo proyecto .NET

### Ventajas:
- 🚀 Despliegue más simple (un solo ejecutable)
- 🔧 Menos dependencias (no más node_modules)
- 🏃 Arranque más rápido
- 🔒 Mejor seguridad (server-side rendering)
- 📦 Menor tamaño de distribución

## 🎯 Próximos Pasos

1. **Producción:**
   - Configurar secretos (Azure Key Vault, AWS Secrets Manager)
   - Habilitar HTTPS
   - Configurar logging persistente
   - Ver: `PRODUCTION-GUIDE.md`

2. **Personalización:**
   - Modificar estilos en `wwwroot/css/site.css`
   - Agregar logo en `Pages/Shared/_Layout.cshtml`
   - Personalizar colores de Bootstrap

3. **Extensiones:**
   - Agregar autenticación (ASP.NET Identity)
   - Implementar reportes en PDF
   - Agregar gráficos con Chart.js

## 📞 Soporte

Para problemas o dudas:
1. Revisa esta guía
2. Consulta `README.md` principal
3. Revisa logs en consola
4. Contacta al equipo de desarrollo

---

**¡Disfruta tu nueva aplicación Notifier con Razor Pages! 🎉**

