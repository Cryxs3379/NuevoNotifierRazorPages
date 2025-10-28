using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi.Models;
using Microsoft.Extensions.Options;
using Polly;
using Polly.CircuitBreaker;
using Polly.Extensions.Http;
using NotifierAPI.Configuration;
using NotifierAPI.Helpers;
using NotifierAPI.Middleware;
using NotifierAPI.Models;
using NotifierAPI.Services;

var builder = WebApplication.CreateBuilder(args);

// Load local configuration file (for development/testing with credentials)
//builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

// Configure JSON serialization
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
    options.SerializerOptions.WriteIndented = false;
});

// Configure settings
var esendexSettings = builder.Configuration.GetSection("Esendex").Get<EsendexSettings>() ?? new EsendexSettings();
var apiKeySettings = builder.Configuration.GetSection("ApiKey").Get<ApiKeySettings>() ?? new ApiKeySettings();
var outputCacheSettings = builder.Configuration.GetSection("OutputCache").Get<OutputCacheSettings>() ?? new OutputCacheSettings();

builder.Services.AddSingleton(esendexSettings);
builder.Services.AddSingleton(apiKeySettings);
builder.Services.AddSingleton(outputCacheSettings);
builder.Services.AddSingleton<MessageStream>();

// Check environment variables OR configuration file for credentials
var esendexUser = Environment.GetEnvironmentVariable("ESENDEX_USER") 
    ?? builder.Configuration["Esendex:Username"];
var esendexApiPassword = Environment.GetEnvironmentVariable("ESENDEX_API_PASSWORD") 
    ?? builder.Configuration["Esendex:ApiPassword"];
var hasCredentials = !string.IsNullOrEmpty(esendexUser) && !string.IsNullOrEmpty(esendexApiPassword);

// Settings
builder.Services.Configure<EsendexSettings>(builder.Configuration.GetSection("Esendex"));
builder.Services.AddSingleton(sp => sp.GetRequiredService<IOptions<EsendexSettings>>().Value);

// HttpClient: BaseUrl + Basic Auth (Username:ApiPassword) + Accept JSON
builder.Services.AddHttpClient<EsendexSendService>((sp, client) =>
{
    var cfg = sp.GetRequiredService<EsendexSettings>();
    var baseUrl = string.IsNullOrWhiteSpace(cfg.BaseUrl) ? "https://api.esendex.com/v1.0/" : cfg.BaseUrl!;
    client.BaseAddress = new Uri(baseUrl);

    var raw = $"{cfg.Username}:{cfg.ApiPassword}";
    var token = Convert.ToBase64String(Encoding.UTF8.GetBytes(raw));
    client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", token);

    client.DefaultRequestHeaders.Accept.Clear();
    client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
});

// Selector de servicio (real si hay credenciales, si no mock)
builder.Services.AddScoped<ISendService>(sp =>
{
    var cfg = sp.GetRequiredService<EsendexSettings>();
    var hasCreds = !string.IsNullOrWhiteSpace(cfg.Username)
                   && !string.IsNullOrWhiteSpace(cfg.ApiPassword)
                   && !string.IsNullOrWhiteSpace(cfg.AccountReference);
    return hasCreds ? sp.GetRequiredService<EsendexSendService>()
                    : ActivatorUtilities.CreateInstance<MockSendService>(sp);
});

// Configure Watcher settings
builder.Services.Configure<WatcherSettings>(builder.Configuration.GetSection("Watcher"));
builder.Services.AddSingleton(sp => sp.GetRequiredService<IOptions<WatcherSettings>>().Value);
builder.Services.AddHostedService<InboxWatcher>();

// Register appropriate service based on credentials
if (hasCredentials)
{
    builder.Logging.AddFilter("NotifierAPI.Services.EsendexInboxService", LogLevel.Debug);
    
    // Named HttpClient with Polly resilience policies
    builder.Services.AddHttpClient("Esendex")
        .ConfigureHttpClient(client =>
        {
            client.BaseAddress = new Uri(esendexSettings.BaseUrl ?? "https://api.esendex.com/v1.0/");
            client.Timeout = TimeSpan.FromSeconds(esendexSettings.TimeoutSeconds);
        })
        .AddTransientHttpErrorPolicy(policyBuilder =>
            policyBuilder.WaitAndRetryAsync(
                esendexSettings.RetryCount,
                retryAttempt => TimeSpan.FromMilliseconds(
                    esendexSettings.RetryDelayMilliseconds * Math.Pow(2, retryAttempt - 1))))
        .AddTransientHttpErrorPolicy(policyBuilder =>
            policyBuilder.CircuitBreakerAsync(
                handledEventsAllowedBeforeBreaking: esendexSettings.CircuitBreakerFailureThreshold,
                durationOfBreak: TimeSpan.FromSeconds(esendexSettings.CircuitBreakerBreakDuration)));
    
    builder.Services.AddScoped<IInboxService>(serviceProvider =>
    {
        var httpClientFactory = serviceProvider.GetRequiredService<IHttpClientFactory>();
        var httpClient = httpClientFactory.CreateClient("Esendex");
        var logger = serviceProvider.GetRequiredService<ILogger<EsendexInboxService>>();
        return new EsendexInboxService(httpClient, logger, esendexSettings, esendexUser!, esendexApiPassword!);
    });
    
    builder.Logging.AddConsole();
}
else
{
    builder.Services.AddScoped<IInboxService, MockInboxService>();
    builder.Logging.AddConsole();
}

// Configure CORS
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? new[] { "http://localhost:5173" };
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (builder.Environment.IsProduction() && allowedOrigins.Any(o => o.Contains("*")))
        {
            throw new InvalidOperationException("Wildcard CORS origins are not allowed in Production");
        }
        
        policy.WithOrigins(allowedOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .WithExposedHeaders("X-Total-Count", "Link");
    });
});

// Add Razor Pages
builder.Services.AddRazorPages();
builder.Services.AddControllersWithViews(); // Para soporte completo de MVC si lo necesitas

// Add Problem Details
builder.Services.AddProblemDetails();

// Add Output Caching
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(policyBuilder => 
        policyBuilder.Expire(TimeSpan.FromSeconds(outputCacheSettings.DefaultExpirationSeconds)));
    
    options.AddPolicy("MessagesCache", policyBuilder => policyBuilder
        .Expire(TimeSpan.FromSeconds(outputCacheSettings.DefaultExpirationSeconds))
        .SetVaryByQuery("page", "pageSize", "direction", "accountRef"));
});

// Configure HttpClient for calling the MissedCalls API
builder.Services.AddHttpClient("MissedCallsAPI", client =>
{
    var missedCallsApiUrl = builder.Configuration["MissedCallsAPI:BaseUrl"] ?? "http://localhost:5000";
    client.BaseAddress = new Uri(missedCallsApiUrl);
    client.Timeout = TimeSpan.FromSeconds(30);
});

// Register MissedCallsService
builder.Services.AddScoped<IMissedCallsService, MissedCallsService>();

// Add Swagger/OpenAPI (only in Development)
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(options =>
    {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
            Title = "Notifier API - Esendex Integration",
            Version = "v1",
            Description = "API para integración con Esendex SMS service. Permite consultar mensajes entrantes con paginación y filtros.",
            Contact = new OpenApiContact
            {
                Name = "Equipo de Desarrollo",
                Email = "dev@empresa.com"
            }
        });

        // Add API Key header
        if (apiKeySettings.Enabled)
        {
            options.AddSecurityDefinition("ApiKey", new OpenApiSecurityScheme
            {
                Description = "API Key needed to access the endpoints. X-API-Key: My_API_Key",
                In = ParameterLocation.Header,
                Name = "X-API-Key",
                Type = SecuritySchemeType.ApiKey
            });

            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "ApiKey"
                        }
                    },
                    Array.Empty<string>()
                }
            });
        }
    });
}

var app = builder.Build();

// Configure middleware
app.UseExceptionHandler();
app.UseStatusCodePages();

// Serve static files (CSS, JS, images)
app.UseStaticFiles();

// Enable Swagger UI (only in Development)
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "Notifier API v1");
        options.RoutePrefix = "swagger";
    });
}

app.UseCors();
app.UseOutputCache();

// Routing
app.UseRouting();

// Authorization
app.UseAuthorization();

// Map Razor Pages
app.MapRazorPages();

// API Key Middleware (only for API endpoints)
app.UseMiddleware<ApiKeyMiddleware>();

// Middleware for validation and error handling
app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (BrokenCircuitException ex)
    {
        app.Logger.LogError(ex, "Circuit breaker is open");
        context.Response.StatusCode = 503;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 503,
            Title = "Service Temporarily Unavailable",
            Detail = "The Esendex service is temporarily unavailable due to repeated errors. Please try again later.",
            Instance = context.Request.Path
        });
    }
    catch (UnauthorizedAccessException ex)
    {
        context.Response.StatusCode = 401;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 401,
            Title = "Esendex Authentication Failed",
            Detail = ex.Message,
            Instance = context.Request.Path
        });
    }
    catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.BadGateway)
    {
        context.Response.StatusCode = 502;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 502,
            Title = "Esendex Service Unavailable",
            Detail = "Unable to connect to Esendex service. Please try again later.",
            Instance = context.Request.Path
        });
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Unhandled exception");
        context.Response.StatusCode = 500;
        await context.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = 500,
            Title = "Internal Server Error",
            Detail = app.Environment.IsDevelopment() ? ex.Message : "An error occurred processing your request.",
            Instance = context.Request.Path
        });
    }
});

// Health endpoint
app.MapGet("/api/health", (IInboxService inboxService) =>
{
    return Results.Ok(new HealthResponse
    {
        Status = "ok",
        EsendexConfigured = inboxService.IsConfigured()
    });
})
.WithName("GetHealth")
.WithTags("Health")
.WithOpenApi(operation => 
{
    operation.Summary = "Health check endpoint";
    operation.Description = "Verifica el estado de la API y si las credenciales de Esendex están configuradas.";
    return operation;
});

// ==================== SSE STREAM ====================

// Messages stream endpoint (Server-Sent Events)
app.MapGet("/api/v1/stream/messages", async (
    HttpContext context,
    ApiKeySettings apiKeySettings,
    MessageStream stream) =>
{
    // Validación API Key por query cuando esté habilitada
    if (apiKeySettings.Enabled)
    {
        var apiKey = context.Request.Query["apiKey"].ToString();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            context.Response.StatusCode = 401;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = 401,
                Title = "API Key Required",
                Detail = "Use ?apiKey=... en la URL para este endpoint SSE"
            });
            return;
        }
        if (!string.Equals(apiKey, apiKeySettings.Value, StringComparison.Ordinal))
        {
            context.Response.StatusCode = 403;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = 403,
                Title = "Invalid API Key",
                Detail = "La API Key proporcionada no es válida"
            });
            return;
        }
    }

    context.Response.Headers.CacheControl = "no-cache";
    context.Response.Headers.Connection = "keep-alive";
    context.Response.ContentType = "text/event-stream";

    var ct = context.RequestAborted;
    await foreach (var evt in stream.ReadEventsAsync(ct))
    {
        await context.Response.WriteAsync(evt, ct);
        await context.Response.Body.FlushAsync(ct);
    }
})
.WithName("MessagesStream")
.WithTags("Stream")
.WithOpenApi(operation => 
{
    operation.Summary = "Server-Sent Events stream para mensajes";
    operation.Description = "Stream en tiempo real de nuevos mensajes. Usa ?apiKey=... si la API Key está habilitada.";
    return operation;
});

// ==================== API V1 ====================

// Messages endpoint V1
app.MapGet("/api/v1/messages", async (
    [FromQuery] string direction,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 50,
    [FromQuery] string? accountRef = null,
    IInboxService inboxService = null!,
    EsendexSettings settings = null!,
    MessageStream messageStream = null!,
    HttpContext httpContext = default!,
    CancellationToken cancellationToken = default) =>
{
    // Validate direction - now supports both inbound and outbound
    if (string.IsNullOrEmpty(direction) || 
        (!direction.Equals("inbound", StringComparison.OrdinalIgnoreCase) && 
         !direction.Equals("outbound", StringComparison.OrdinalIgnoreCase)))
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = "Parameter 'direction' must be 'inbound' or 'outbound'"
        });
    }

    // Validate page
    if (page < 1)
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = "Parameter 'page' must be >= 1"
        });
    }

    // Validate pageSize with configurable limits
    if (pageSize < settings.MinPageSize || pageSize > settings.MaxPageSize)
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = $"Parameter 'pageSize' must be between {settings.MinPageSize} and {settings.MaxPageSize}"
        });
    }

    var messages = await inboxService.GetMessagesAsync(direction, page, pageSize, accountRef, cancellationToken);
    
    // Add pagination headers
    PaginationHelper.AddPaginationHeaders(
        httpContext.Response,
        httpContext.Request,
        page,
        pageSize,
        messages.Total,
        direction,
        accountRef
    );
    
    // Disparar evento SSE si hay mensajes nuevos
    var latest = messages.Items.FirstOrDefault();
    if (latest is not null)
    {
        messageStream.NotifyNewMessage(latest.Id, latest.ReceivedUtc);
    }
    
    return Results.Ok(messages);
})
.WithName("GetMessagesV1")
.WithTags("Messages V1")
.CacheOutput("MessagesCache")
.WithOpenApi(operation => 
{
    operation.Summary = "Obtener mensajes entrantes";
    operation.Description = @"Obtiene la lista de mensajes SMS entrantes desde Esendex con paginación.

**Cabeceras de respuesta:**
- `X-Total-Count`: Total de mensajes disponibles
- `Link`: Enlaces de navegación (first, prev, next, last)

**Cache:** 30 segundos (configurable)";
    
    return operation;
});

// ==================== Legacy endpoints (backwards compatibility) ====================

// Messages endpoint (legacy - redirects to v1)
app.MapGet("/api/messages", async (
    [FromQuery] string direction,
    [FromQuery] int page = 1,
    [FromQuery] int pageSize = 50,
    [FromQuery] string? accountRef = null,
    IInboxService inboxService = null!,
    EsendexSettings settings = null!,
    HttpContext httpContext = default!,
    CancellationToken cancellationToken = default) =>
{
    // Same implementation as V1 for backwards compatibility
    if (string.IsNullOrEmpty(direction) || 
        (!direction.Equals("inbound", StringComparison.OrdinalIgnoreCase) && 
         !direction.Equals("outbound", StringComparison.OrdinalIgnoreCase)))
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = "Parameter 'direction' must be 'inbound' or 'outbound'"
        });
    }

    if (page < 1)
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = "Parameter 'page' must be >= 1"
        });
    }

    if (pageSize < settings.MinPageSize || pageSize > settings.MaxPageSize)
    {
        return Results.BadRequest(new ProblemDetails
        {
            Status = 400,
            Title = "Invalid Parameter",
            Detail = $"Parameter 'pageSize' must be between {settings.MinPageSize} and {settings.MaxPageSize}"
        });
    }

    var messages = await inboxService.GetMessagesAsync(direction, page, pageSize, accountRef, cancellationToken);
    
    // Add pagination headers
    PaginationHelper.AddPaginationHeaders(
        httpContext.Response,
        httpContext.Request,
        page,
        pageSize,
        messages.Total,
        direction,
        accountRef
    );
    
    return Results.Ok(messages);
})
.WithName("GetMessages")
.WithTags("Messages (Legacy)")
.CacheOutput("MessagesCache")
.WithOpenApi(operation => 
{
    operation.Summary = "[LEGACY] Obtener mensajes entrantes";
    operation.Description = "Endpoint legacy. Use /api/v1/messages para nuevas implementaciones.";
    operation.Deprecated = true;
    return operation;
});

// ==================== SEND MESSAGES ====================

// Send message endpoint
app.MapPost("/api/v1/messages/reply", async (
    [FromBody] SendMessageRequest req,
    ISendService sender,
    MessageStream stream,
    ILoggerFactory loggerFactory,
    CancellationToken ct) =>
{
    var logger = loggerFactory.CreateLogger("SendReply");

    if (string.IsNullOrWhiteSpace(req.To) || !System.Text.RegularExpressions.Regex.IsMatch(req.To, @"^\+\d{6,15}$"))
        return Results.Problem(statusCode: 400, title: "Invalid 'to'", detail: "Use formato E.164, p. ej. +34600111222");
    if (string.IsNullOrWhiteSpace(req.Message))
        return Results.Problem(statusCode: 400, title: "Invalid 'message'", detail: "No puede estar vacío");

    logger.LogInformation("Reply: to=****{Last3}, len={Len}, accRef={Acc}",
        req.To.Length >= 3 ? req.To[^3..] : req.To, req.Message.Length, req.AccountRef);

    var result = await sender.SendAsync(req.To, req.Message, req.AccountRef, ct);

    stream.Notify(new { type = "message_sent", id = result.Id, to = req.To, submittedUtc = result.SubmittedUtc.ToString("O") });

    return Results.Ok(new SendMessageResponse
    {
        Id = result.Id,
        To = req.To,
        Message = req.Message,
        SubmittedUtc = result.SubmittedUtc
    });
})
.WithName("SendReply");

app.Logger.LogInformation("Notifier API starting...");
app.Logger.LogInformation("Environment: {Environment}", app.Environment.EnvironmentName);
app.Logger.LogInformation("Esendex credentials configured: {IsConfigured}", hasCredentials);
app.Logger.LogInformation("API Key protection: {Enabled}", apiKeySettings.Enabled);
app.Logger.LogInformation("Output caching: {Seconds}s", outputCacheSettings.DefaultExpirationSeconds);
app.Logger.LogInformation("Razor Pages UI: http://localhost:5080");

if (app.Environment.IsDevelopment())
{
    app.Logger.LogInformation("Swagger UI: http://localhost:5080/swagger");
}

app.Run("http://localhost:5080");