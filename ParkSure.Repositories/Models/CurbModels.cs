namespace ParkSure.Models;

public enum PinMode { Gps, Tap }
public enum LookupOutcome { Found, Ambiguous, NoCurb, NoDataArea, NoSigns }

public record CurbCandidate(int SegmentId, string Side, string? StreetName,
                            string? Borough, double DistanceM);

public record CurbSign(int SignId, string PanneauId, string? PoteauId, string CodeRpa,
                       string? DescriptionRpa, decimal Confidence);

public record CurbLookupResult(LookupOutcome Outcome,
                               IReadOnlyList<CurbCandidate> Curbs,
                               IReadOnlyList<CurbSign> Signs);