using System.Text.Json;

namespace ParkSure.Evaluation;

/// <summary>
/// Turns one parking_rule row into a ParkingRule. Anything that cannot be read exactly
/// returns null plus a problem text, and the evaluator then treats the code as "no usable rule".
/// </summary>
public static class RuleParser
{
    private static readonly HashSet<string> AllowedKeys = new() { "days", "from", "to", "months" };

    public static ParkingRule? TryParse(
        string code, string? ruleType, int priority, bool reviewed,
        string? windowsJson, string? permitSector, int? maxMinutes, out string? problem)
    {
        problem = null;

        if (!reviewed) { problem = "rule is not reviewed"; return null; }

        RuleKind? kind = ruleType switch
        {
            "no_stopping" => RuleKind.NoStopping,
            "no_parking" => RuleKind.NoParking,
            "no_parking_except_permit" => RuleKind.NoParkingExceptPermit,
            "duration_limit" => RuleKind.DurationLimit,
            "paid_parking" => RuleKind.PaidParking,
            _ => null
        };
        if (kind is null) { problem = $"unrecognised rule type '{ruleType}'"; return null; }

        if (string.IsNullOrWhiteSpace(windowsJson)) { problem = "windows is missing"; return null; }

        var windows = new List<RuleWindow>();
        try
        {
            using var doc = JsonDocument.Parse(windowsJson);
            if (doc.RootElement.ValueKind != JsonValueKind.Array) { problem = "windows is not an array"; return null; }
            foreach (var element in doc.RootElement.EnumerateArray())
            {
                var window = ParseWindow(element, out var windowProblem);
                if (window is null) { problem = windowProblem; return null; }
                windows.Add(window);
            }
        }
        catch (JsonException) { problem = "windows is not valid JSON"; return null; }

        return new ParkingRule(code, kind.Value, priority, windows, permitSector, maxMinutes);
    }

    private static RuleWindow? ParseWindow(JsonElement el, out string? problem)
    {
        problem = null;
        if (el.ValueKind != JsonValueKind.Object) { problem = "a window is not an object"; return null; }

        List<int>? days = null, months = null;
        string? from = null, to = null;

        foreach (var prop in el.EnumerateObject())
        {
            if (!AllowedKeys.Contains(prop.Name)) { problem = $"unknown window key '{prop.Name}'"; return null; }
            switch (prop.Name)
            {
                case "days":
                    if (prop.Value.ValueKind != JsonValueKind.Null && !TryInts(prop.Value, out days)) { problem = "days is not a list of integers"; return null; }
                    break;
                case "months":
                    if (prop.Value.ValueKind != JsonValueKind.Null && !TryInts(prop.Value, out months)) { problem = "months is not a list of integers"; return null; }
                    break;
                case "from":
                    if (prop.Value.ValueKind != JsonValueKind.String) { problem = "from is not text"; return null; }
                    from = prop.Value.GetString();
                    break;
                case "to":
                    if (prop.Value.ValueKind != JsonValueKind.String) { problem = "to is not text"; return null; }
                    to = prop.Value.GetString();
                    break;
            }
        }

        var window = RuleWindow.TryCreate(days, from, to, months);
        if (window is null) problem = "window is unreadable (times, days or months out of range)";
        return window;
    }

    private static bool TryInts(JsonElement el, out List<int>? values)
    {
        values = null;
        if (el.ValueKind != JsonValueKind.Array) return false;
        var list = new List<int>();
        foreach (var item in el.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Number || !item.TryGetInt32(out var n)) return false;
            list.Add(n);
        }
        values = list;
        return true;
    }
}
