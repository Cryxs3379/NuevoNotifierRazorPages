namespace NotifierAPI.Models;

public class MissedCallDto
{
    public int Id { get; set; }
    public DateTime DateAndTime { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public int Status { get; set; }
    public bool? ClientCalledAgain { get; set; }
    public DateTime? AnswerCall { get; set; }
}

public class MissedCallsResponse
{
    public bool Success { get; set; }
    public int Count { get; set; }
    public List<MissedCallDto> Data { get; set; } = new();
}

public class MissedCallsStatsResponse
{
    public int TotalMissedCalls { get; set; }
    public int TodayMissedCalls { get; set; }
    public int ThisWeekMissedCalls { get; set; }
    public object? LastMissedCall { get; set; }
}

