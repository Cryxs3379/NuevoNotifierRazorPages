using Microsoft.AspNetCore.Mvc;
using NotifierAPI.Configuration;

namespace NotifierAPI.Middleware;

public class ApiKeyMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ApiKeySettings _settings;
    private readonly ILogger<ApiKeyMiddleware> _logger;

    public ApiKeyMiddleware(RequestDelegate next, ApiKeySettings settings, ILogger<ApiKeyMiddleware> logger)
    {
        _next = next;
        _settings = settings;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip if API Key is not enabled
        if (!_settings.Enabled)
        {
            await _next(context);
            return;
        }

        // Only check API key for /api/v1/messages endpoints
        if (!context.Request.Path.StartsWithSegments("/api/v1/messages"))
        {
            await _next(context);
            return;
        }

        // Check for X-API-Key header
        if (!context.Request.Headers.TryGetValue("X-API-Key", out var extractedApiKey))
        {
            _logger.LogWarning("API Key missing for request to {Path}", context.Request.Path);
            context.Response.StatusCode = 401;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = 401,
                Title = "API Key Required",
                Detail = "X-API-Key header is required for this endpoint",
                Instance = context.Request.Path
            });
            return;
        }

        // Validate API key
        if (!string.Equals(extractedApiKey, _settings.Value, StringComparison.Ordinal))
        {
            _logger.LogWarning("Invalid API Key provided for request to {Path}", context.Request.Path);
            context.Response.StatusCode = 403;
            context.Response.ContentType = "application/json";
            await context.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Status = 403,
                Title = "Invalid API Key",
                Detail = "The provided API Key is not valid",
                Instance = context.Request.Path
            });
            return;
        }

        await _next(context);
    }
}

