namespace NotifierAPI.Configuration;

public class WatcherSettings
{
    public bool Enabled { get; set; } = true;
    public int IntervalSeconds { get; set; } = 5;
    public string? AccountRef { get; set; }
}
