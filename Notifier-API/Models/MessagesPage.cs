namespace NotifierAPI.Models;

public class MessagesPage
{
    public IReadOnlyList<MessageDto> Items { get; init; } = Array.Empty<MessageDto>();
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int Total { get; init; }
    public int TotalPages => (int)Math.Ceiling((double)Total / Math.Max(1, PageSize));
}


