using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using NotifierAPI.Configuration;

namespace NotifierAPI.Services;

public class InboxWatcher : BackgroundService
{
    private readonly ILogger<InboxWatcher> _logger;
    private readonly IInboxService _inbox;
    private readonly MessageStream _stream;
    private readonly WatcherSettings _settings;

    private string? _lastSeenId;

    public InboxWatcher(ILogger<InboxWatcher> logger, IInboxService inbox, MessageStream stream, WatcherSettings settings)
    {
        _logger = logger;
        _inbox = inbox;
        _stream = stream;
        _settings = settings;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!_settings.Enabled)
        {
            _logger.LogInformation("InboxWatcher disabled.");
            return;
        }

        _logger.LogInformation("InboxWatcher started. Interval: {Interval}s, AccountRef: {AccountRef}",
            _settings.IntervalSeconds, _settings.AccountRef ?? "(none)");

        var delay = TimeSpan.FromSeconds(Math.Max(1, _settings.IntervalSeconds));

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Pedimos los primeros 10 mensajes para detectar todos los cambios
                var resp = await _inbox.GetMessagesAsync("inbound", 1, 10, _settings.AccountRef, stoppingToken);
                var messages = resp.Items.ToList();

                if (messages.Any())
                {
                    // Detectar todos los mensajes nuevos (no solo el último)
                    var newMessages = messages.Where(m => m.Id != _lastSeenId).ToList();
                    
                    if (newMessages.Any())
                    {
                        // Notificar todos los mensajes nuevos (del más antiguo al más reciente)
                        foreach (var msg in newMessages.OrderBy(m => m.ReceivedUtc))
                        {
                            _stream.NotifyNewMessage(msg.Id, msg.ReceivedUtc);
                            _logger.LogInformation("New message detected: {Id} at {At}", msg.Id, msg.ReceivedUtc);
                        }
                        
                        // Actualizar el último ID visto al más reciente
                        _lastSeenId = messages.First().Id;
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                // shutdown
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "InboxWatcher tick failed");
            }

            try { await Task.Delay(delay, stoppingToken); } catch { /* canceled */ }
        }

        _logger.LogInformation("InboxWatcher stopped.");
    }
}