# 🚀 Inicio Rápido - Notifier con Razor Pages

## Opción 1: Script Automático (Recomendado)

Ejecuta el script desde la raíz del proyecto:

```powershell
.\start-notifier.ps1
```

Este script:
- ✅ Inicia la API de llamadas perdidas (puerto 5000)
- ✅ Inicia Notifier con Razor Pages (puerto 5080)
- ✅ Muestra todas las URLs disponibles

## Opción 2: Manual

### Paso 1: Iniciar API de Llamadas
```powershell
cd Notifier-APiCalls
dotnet run
```

### Paso 2: Iniciar Notifier (en otra terminal)
```powershell
cd Notifier-API
dotnet run
```

## 🌐 URLs Disponibles

Una vez iniciado, accede a:

| Servicio | URL |
|----------|-----|
| **Aplicación Web** | http://localhost:5080 |
| Swagger API | http://localhost:5080/swagger |
| API Llamadas | http://localhost:5000 |

## 📱 Páginas Disponibles

| Página | URL | Descripción |
|--------|-----|-------------|
| **Inicio** | http://localhost:5080/ | Dashboard principal |
| **Mensajes** | http://localhost:5080/Messages/Index | Ver mensajes SMS |
| **Enviar** | http://localhost:5080/Messages/Reply | Enviar mensaje SMS |
| **Llamadas** | http://localhost:5080/Calls/Index | Ver llamadas perdidas |

## ⚙️ Configuración Rápida

### Credenciales Esendex (Opcional)

Si tienes credenciales de Esendex, edita `Notifier-API/appsettings.json`:

```json
{
  "Esendex": {
    "Username": "tu.email@empresa.com",
    "ApiPassword": "EX1234567890abcdefghijk",
    "AccountReference": "EX0375657"
  }
}
```

**Nota:** Sin credenciales, la aplicación funciona en modo MOCK con datos de ejemplo.

### Base de Datos de Llamadas

Asegúrate de que `Notifier-APiCalls/appsettings.json` tenga la cadena de conexión correcta:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=tu_servidor;Database=tu_bd;..."
  }
}
```

## 🎯 Primer Uso

1. **Abre tu navegador** en http://localhost:5080
2. **Verás el dashboard** con 3 opciones principales
3. **Explora las páginas:**
   - Haz clic en "Ver Mensajes" para ver SMS
   - Haz clic en "Enviar" para enviar un SMS
   - Haz clic en "Ver Llamadas" para llamadas perdidas

## 🆘 Problemas Comunes

### Error: "Puerto 5080 ya está en uso"

**Solución:**
```powershell
# Encuentra el proceso que usa el puerto
netstat -ano | findstr :5080

# Mata el proceso (reemplaza PID)
taskkill /F /PID [número_de_PID]
```

### Error: "No se puede conectar con la API de llamadas"

**Solución:**
- Verifica que `Notifier-APiCalls` esté ejecutándose
- Prueba: http://localhost:5000/api/MissedCalls/test

### Error: "Error de autenticación con Esendex"

**Solución:**
- Si no tienes credenciales, la app funciona en modo MOCK
- Si tienes credenciales, verifica que sean correctas en `appsettings.json`

## 📚 Documentación Completa

- **Guía de Razor Pages:** `RAZOR-PAGES-GUIDE.md`
- **README Principal:** `README.md`
- **Guía de Producción:** `PRODUCTION-GUIDE.md`

## 🛑 Detener los Servicios

Si usaste el script automático:
- Presiona `Ctrl + C`

Si iniciaste manualmente:
- Presiona `Ctrl + C` en cada terminal

---

**¡Listo! Ya puedes usar Notifier con Razor Pages 🎉**

