# ParkSure

**Can I park here?** A Montréal street-parking app that answers honestly.

ParkSure takes a location and a time — latitude, longitude, datetime — and
answers one question: *can I park here?* The answer is one of four:

| Answer | Meaning |
| ------ | ------- |
| 🟢 Allowed | No rule forbids parking here right now. |
| 🟡 Conditions | You can park, but with a limit (time limit, paid parking, a ban starting soon). |
| 🔴 Not allowed | At least one rule forbids parking here right now. |
| ⚪ Unknown | The data can't prove it's safe. The app says so instead of guessing. |

## The one rule above all others: zero false green

A ticket only needs one sign against you. So the app works the same way:
any one forbidding sign on a block makes the whole block red, and when the
data is stale, ambiguous, missing, or low-confidence, the answer is
"unknown" — never a confident green on a guess.

On first open, the app says this plainly, once:

> Parking rules overlap. When they do, we show the strictest one — because
> a ticket only needs one sign against you. And when the data can't prove
> it's safe to park, we say "unknown" instead of guessing.
>
> Rules are shown per block, not per exact meter, in v1.

## How it works

1. **Find the curb.** The nearest curb side within 30 m of the pin.
   No curb found → unknown (`NoCurb`).
2. **Collect the signs.** Every sign linked to that curb side.
   No signs linked → unknown (`NoSigns`). No signs does *not* mean "you can park."
3. **Safety checks first.** A low-confidence sign link (below 0.6) or a
   sign whose code has no reviewed rule turns the whole segment unknown (`LowConfidence`, `NoRule`).
4. **Check each rule at the query time.** Days (ISO 1..7), time range (minutes since midnight), season (months 1..12).
   Overnight windows belong to the day they start on. Timezone calculations operate strictly in `America/Toronto` local wall-clock time.
5. **Decide, strictest wins.** Any active ban → `NotAllowed`. Else any
   active condition → `Conditions`. Else `Allowed`.
6. **Permits.** An optional permit (e.g. SRR sector 198) bypasses only
   `no_parking_except_permit` rules for that sector — never any other rule.
7. **Look-ahead warning.** If parking is allowed now but a ban begins within 60 minutes, status upgrades to `Conditions` with a warning message.
8. **State changes.** Future status expiration (`ValidUntil`) scans upcoming transition boundaries up to 366 days ahead.

Rules are evaluated per block (one curb side = one segment = one colour),
not per exact meter, in v1.

## Stack

- **App:** Flutter (iOS + Android)
- **Backend:** ASP.NET Core (.NET 10) Clean / 3-Tier Architecture
- **Database:** PostgreSQL + PostGIS
- **Testing:** xUnit
- **API (available):**
  - `GET /api/curbs/at?lat=&lon=&mode=&at=&permit=`
  - `GET /api/curbs/lookup?lat=&lon=&mode=`
  - `GET /api/curbs/{segmentId}`
  - `GET /api/health`
  - `GET /api/dev/rule-check` (Development only)

## Data

- **Signs:** Ville de Montréal open data, *Stationnement sur rue — signalisation courante* (~144,690 signs, 1,546 codes). City sign coordinates are approximate and the dataset can lag behind the street, which is one more reason unknown exists.
- **Curbs:** Ville de Montréal *Géobase double* (~91,606 curb sides).
- **Sign text reference:** the December 2015 *Catalogue de signalisation* (backup only — the city's own sign descriptions come first).
- **Dictionary:** Every code's rule is reviewed before it reaches the app. Unreviewed codes → unknown. Nothing ships on an unreviewed guess.

## Project status

| Piece | State |
| ----- | ----- |
| Database schema (7 tables) | ✅ Done |
| Curbs loaded (~91,606 sides) | ✅ Done |
| Signs loaded + linked to curbs (114,426 links) | ✅ Done |
| Reviewed rules | ✅ 200 of 1,546 codes loaded, growing |
| Evaluator (the decision logic) | ✅ Done (Milestone B3: pure zero-I/O engine) |
| Unit Tests | ✅ Done (93/93 tests passing) |
| API | ✅ Done (Milestone B4: integration & `/api/curbs/at`) |
| App UI (Flutter) | 📋 Planned |

## Key decisions (locked for v1)

- **Pure logic engine.** Core evaluation logic is isolated from I/O, database access, network requests, and system clock dependencies.
- **Most-restrictive-wins.** Prohibitions unconditionally override permissions. Priority numbers pick the reason text only — they never change the status.
- **Arrows ignored.** The sign arrow field (`FLECHE_PAN`) is undocumented and unresolved — v1 ignores it entirely.
- **Permits in the MVP.** One SRR permit zone per user, normalized (lowercase, strip non-alphanumerics, strip leading zeros).
- **No-data areas.** The 15 non-Montréal municipalities on the island (DDO, Pointe-Claire, Dorval, …) have no city sign data and return `NoDataArea`, not grey.
- **Middle-of-street taps.** If a tap is nearly equidistant from both sides (within 2.0 m margin), the app returns both candidate lines (`ambiguous`) so the user can choose. GPS checks pick nearest.
- **30 m, inclusive.** Nearest curb within 30.0 m counts; beyond that, unknown (`NoCurb`). Distance is measured to the whole curb line.

## Project layout

ParkSure/
├── ParkSure.Api/            # ASP.NET Core Web API controllers & endpoints
├── ParkSure.Services/       # Application workflows & pure evaluation engine
│   └── Evaluation/          # CurbEvaluator, RuleParser, EvaluationModels
├── ParkSure.Repositories/   # PostGIS spatial queries, Dapper/Npgsql data access
├── ParkSure.Tests/          # xUnit test suite (Fixtures, Spec tests, Edge cases)
├── db/                      # Schema, migrations, bulk rule loading SQL
└── docs/                    # Specifications, ADRs, test scenarios


## Running the tests

Prerequisites: .NET 10 SDK, PostgreSQL + PostGIS.

To run the full unit test suite:

```bash
dotnet test

To run tests with detailed console logs:
Bash

dotnet test --logger "console;verbosity=detailed"

Disclaimer

ParkSure is a guide, not legal advice. City data can lag behind the
street: a sign can exist on a pole before it appears in the data, and vice
versa. Always check the physical signs before you park. If the app and the
street disagree, the street wins.
License

TBD.
EOF