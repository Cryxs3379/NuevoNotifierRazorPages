using NotifierAPI.Models;

namespace NotifierAPI.Services;

public interface IInboxService
{
    Task<MessagesResponse> GetMessagesAsync(string direction, int page, int pageSize, string? accountRef = null, CancellationToken cancellationToken = default);
    bool IsConfigured();
}


