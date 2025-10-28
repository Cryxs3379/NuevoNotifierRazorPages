using System.Text;

namespace NotifierAPI.Helpers;

public static class PaginationHelper
{
    public static void AddPaginationHeaders(HttpResponse response,
                                            HttpRequest request,
                                            int page,
                                            int pageSize,
                                            int total,
                                            string direction,
                                            string? accountRef)
    {
        // Add X-Total-Count header
        response.Headers.Append("X-Total-Count", total.ToString());

        var totalPages = Math.Max(1, (int)Math.Ceiling(total / (double)pageSize));

        List<string> links = new();

        string BuildLink(int targetPage)
        {
            var ub = new UriBuilder
            {
                Scheme = request.Scheme,
                Host = request.Host.Host,
                Path = request.Path, // respeta /api/v1/messages o /api/messages
                Port = request.Host.Port ?? -1
            };

            var query = new Dictionary<string, string?>
            {
                ["direction"] = direction,
                ["page"] = targetPage.ToString(),
                ["pageSize"] = pageSize.ToString(),
                ["accountRef"] = string.IsNullOrWhiteSpace(accountRef) ? null : accountRef
            };

            var qs = string.Join("&",
                query.Where(kv => !string.IsNullOrEmpty(kv.Value))
                     .Select(kv => $"{Uri.EscapeDataString(kv.Key)}={Uri.EscapeDataString(kv.Value!)}"));

            ub.Query = qs;
            return ub.Uri.ToString();
        }

        if (page > 1)
        {
            links.Add($"<{BuildLink(1)}>; rel=\"first\"");
            links.Add($"<{BuildLink(page - 1)}>; rel=\"prev\"");
        }
        if (page < totalPages)
        {
            links.Add($"<{BuildLink(page + 1)}>; rel=\"next\"");
            links.Add($"<{BuildLink(totalPages)}>; rel=\"last\"");
        }

        if (links.Count > 0)
            response.Headers.Append("Link", string.Join(", ", links));
    }
}