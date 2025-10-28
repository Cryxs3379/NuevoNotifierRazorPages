using System.Threading.Channels;
using System.Text.Json;
using System.Runtime.CompilerServices;

namespace NotifierAPI.Services;

public class MessageStream
{
    private readonly Channel<string> _channel = Channel.CreateUnbounded<string>();
    private string? _lastPublishedId;
    private readonly TimeSpan _heartbeat = TimeSpan.FromSeconds(15);

    public void NotifyNewMessage(string id, DateTime receivedUtc)
    {
        // Evitar duplicados triviales
        if (_lastPublishedId == id) return;
        _lastPublishedId = id;

        var payload = JsonSerializer.Serialize(new {
            type = "new_message",
            id,
            receivedUtc = receivedUtc.ToUniversalTime().ToString("O")
        });
        _ = _channel.Writer.WriteAsync($"data: {payload}\n\n");
    }

    public void Notify(object payload)
    {
        var json = JsonSerializer.Serialize(payload);
        _ = _channel.Writer.WriteAsync($"data: {json}\n\n");
    }

    public async IAsyncEnumerable<string> ReadEventsAsync([EnumeratorCancellation] CancellationToken ct)
    {
        var hbNext = DateTime.UtcNow + _heartbeat;

        while (!ct.IsCancellationRequested)
        {
            // Heartbeat
            if (DateTime.UtcNow >= hbNext)
            {
                yield return "data: {\"type\":\"heartbeat\"}\n\n";
                hbNext = DateTime.UtcNow + _heartbeat;
            }

            while (_channel.Reader.TryRead(out var evt))
            {
                yield return evt;
            }

            // Pequeño delay para no quemar CPU
            try { await Task.Delay(500, ct); } catch { }
        }
    }
}
