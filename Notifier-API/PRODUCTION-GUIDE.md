# Guía de Despliegue en Producción

## 🔐 Gestión de Secretos

### ❌ NO usar en producción:
- Variables de entorno directas
- Archivos de configuración con credenciales
- Hardcoded credentials

### ✅ Recomendaciones:

#### Azure
```csharp
// Usar Azure Key Vault
builder.Configuration.AddAzureKeyVault(
    new Uri($"https://{keyVaultName}.vault.azure.net/"),
    new DefaultAzureCredential());

// Acceder a secretos:
var esendexUser = builder.Configuration["ESENDEX-USER"];
var esendexPassword = builder.Configuration["ESENDEX-API-PASSWORD"];
```

#### AWS
```csharp
// Usar AWS Secrets Manager
builder.Configuration.AddSecretsManager(
    configurator: options =>
    {
        options.SecretFilter = entry => entry.Name.StartsWith("notifier/");
    });
```

#### Docker Secrets
```yaml
# docker-compose.yml
services:
  api:
    secrets:
      - esendex_user
      - esendex_password
secrets:
  esendex_user:
    external: true
  esendex_password:
    external: true
```

## 🌐 CORS - Configuración Segura

### Desarrollo
```json
{
  "Cors": {
    "AllowedOrigins": ["http://localhost:5173"]
  }
}
```

### Producción
```json
{
  "Cors": {
    "AllowedOrigins": [
      "https://app.tuempresa.com",
      "https://www.tuempresa.com"
    ]
  }
}
```

### Configuración avanzada
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .WithMethods("GET")  // Solo GET para esta API
              .WithHeaders("Authorization", "Content-Type")
              .SetIsOriginAllowedToAllowWildcardSubdomains()
              .WithExposedHeaders("X-Pagination")
              .SetPreflightMaxAge(TimeSpan.FromMinutes(10));
    });
});
```

## 🔒 HTTPS y Certificados

### Configuración obligatoria en producción:

```csharp
// Program.cs
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
    app.UseHsts();
}

// Configure Kestrel
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.AddServerHeader = false;
    serverOptions.Limits.MaxRequestBodySize = 10 * 1024; // 10 KB
    
    serverOptions.ConfigureHttpsDefaults(httpsOptions =>
    {
        httpsOptions.SslProtocols = System.Security.Authentication.SslProtocols.Tls12 | 
                                    System.Security.Authentication.SslProtocols.Tls13;
    });
});
```

## 🚦 Rate Limiting

### Implementación recomendada:

```bash
dotnet add package AspNetCoreRateLimit
```

```csharp
// Program.cs
builder.Services.AddMemoryCache();
builder.Services.Configure<IpRateLimitOptions>(options =>
{
    options.EnableEndpointRateLimiting = true;
    options.StackBlockedRequests = false;
    options.HttpStatusCode = 429;
    options.GeneralRules = new List<RateLimitRule>
    {
        new RateLimitRule
        {
            Endpoint = "GET:/api/messages",
            Period = "1m",
            Limit = 30
        },
        new RateLimitRule
        {
            Endpoint = "GET:/api/health",
            Period = "1s",
            Limit = 10
        }
    };
});

builder.Services.AddInMemoryRateLimiting();
builder.Services.AddSingleton<IRateLimitConfiguration, RateLimitConfiguration>();

// En el pipeline
app.UseIpRateLimiting();
```

## 📊 Logging y Monitoring

### Serilog (Recomendado)

```bash
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.Console
dotnet add package Serilog.Sinks.File
dotnet add package Serilog.Enrichers.Environment
```

```csharp
using Serilog;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithEnvironment()
    .Enrich.WithMachineName()
    .WriteTo.Console()
    .WriteTo.File("logs/notifier-.log", 
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 30)
    .CreateLogger();

builder.Host.UseSerilog();
```

### Application Insights (Azure)

```bash
dotnet add package Microsoft.ApplicationInsights.AspNetCore
```

```csharp
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["ApplicationInsights:ConnectionString"];
});
```

### Filtrar información sensible:

```csharp
builder.Services.AddLogging(logging =>
{
    logging.AddFilter((category, level) =>
    {
        // Nunca loggear credenciales
        if (category.Contains("EsendexInboxService") && level == LogLevel.Trace)
            return false;
        
        return level >= LogLevel.Information;
    });
});
```

## 🏥 Health Checks Avanzados

```bash
dotnet add package AspNetCore.HealthChecks.Uris
```

```csharp
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy())
    .AddUrlGroup(new Uri("https://api.esendex.com"), 
        name: "esendex-api",
        timeout: TimeSpan.FromSeconds(3))
    .AddCheck<EsendexCredentialsHealthCheck>("esendex-credentials");

app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});
```

## 🐳 Docker

### Dockerfile

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["Notifier-API.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Security: Run as non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser /app
USER appuser

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "Notifier-API.dll"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  notifier-api:
    build: .
    ports:
      - "5080:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
    secrets:
      - esendex_user
      - esendex_password
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s

secrets:
  esendex_user:
    file: ./secrets/esendex_user.txt
  esendex_password:
    file: ./secrets/esendex_password.txt
```

## 🔍 Auditoría y Seguridad

### Headers de Seguridad

```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Add("X-Frame-Options", "DENY");
    context.Response.Headers.Add("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Add("Referrer-Policy", "no-referrer");
    context.Response.Headers.Add("Content-Security-Policy", "default-src 'none'");
    
    await next();
});
```

### API Key Authentication (opcional)

```csharp
// Middleware para validar API Key
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api/messages"))
    {
        if (!context.Request.Headers.TryGetValue("X-API-Key", out var apiKey))
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "API Key required" });
            return;
        }

        var validApiKey = builder.Configuration["ApiKey"];
        if (apiKey != validApiKey)
        {
            context.Response.StatusCode = 403;
            await context.Response.WriteAsJsonAsync(new { error = "Invalid API Key" });
            return;
        }
    }
    
    await next();
});
```

## 📈 Performance

### Response Caching

```csharp
builder.Services.AddResponseCaching();

app.UseResponseCaching();

// En el endpoint
app.MapGet("/api/messages", async (...) =>
{
    // ...
})
.WithMetadata(new ResponseCacheAttribute 
{ 
    Duration = 60, 
    VaryByQueryKeys = new[] { "page", "pageSize", "direction" }
});
```

### Output Caching (.NET 8)

```csharp
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(builder => builder.Expire(TimeSpan.FromSeconds(60)));
});

app.UseOutputCache();

app.MapGet("/api/messages", async (...) =>
{
    // ...
})
.CacheOutput(policy => policy
    .Expire(TimeSpan.FromSeconds(30))
    .SetVaryByQuery("page", "pageSize", "direction"));
```

## 🚀 Despliegue

### Azure App Service

```bash
# Login
az login

# Crear App Service
az webapp create \
  --resource-group NotifierRG \
  --plan NotifierPlan \
  --name notifier-api \
  --runtime "DOTNET|8.0"

# Configurar secretos desde Key Vault
az webapp config appsettings set \
  --resource-group NotifierRG \
  --name notifier-api \
  --settings ESENDEX_USER="@Microsoft.KeyVault(SecretUri=https://myvault.vault.azure.net/secrets/esendex-user/)"

# Deploy
dotnet publish -c Release
cd bin/Release/net8.0/publish
az webapp deployment source config-zip \
  --resource-group NotifierRG \
  --name notifier-api \
  --src publish.zip
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notifier-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: notifier-api
  template:
    metadata:
      labels:
        app: notifier-api
    spec:
      containers:
      - name: api
        image: notifier-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: ESENDEX_USER
          valueFrom:
            secretKeyRef:
              name: esendex-credentials
              key: username
        - name: ESENDEX_API_PASSWORD
          valueFrom:
            secretKeyRef:
              name: esendex-credentials
              key: password
        livenessProbe:
          httpGet:
            path: /api/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: notifier-api-service
spec:
  selector:
    app: notifier-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

## 📋 Checklist Pre-Producción

- [ ] Credenciales en Key Vault/Secrets Manager
- [ ] HTTPS configurado con certificados válidos
- [ ] CORS configurado solo para dominios permitidos
- [ ] Rate limiting implementado
- [ ] Logging centralizado configurado
- [ ] Health checks implementados
- [ ] Monitoring y alertas configurados
- [ ] API Keys o autenticación implementada
- [ ] Headers de seguridad añadidos
- [ ] Response/Output caching configurado
- [ ] Docker/Kubernetes configurado
- [ ] Backup y disaster recovery planeado
- [ ] Documentación actualizada
- [ ] Tests de carga realizados
- [ ] Plan de rollback definido

## 📞 Contacto y Soporte

Para cuestiones de producción, contacta con el equipo DevOps o el responsable de infraestructura.


