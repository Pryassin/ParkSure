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
   No curb found → unknown.
2. **Collect the signs.** Every sign linked to that curb side.
   No signs linked → unknown. No signs does *not* mean "you can park."
3. **Safety checks first.** A low-confidence sign link (below 0.6) or a
   sign whose code has no reviewed rule turns the whole segment unknown.
4. **Check each rule at the query time.** Days, time range, season.
   Overnight windows belong to the day they start on.
5. **Decide, strictest wins.** Any active ban → not allowed. Else any
   active condition → conditions. Else allowed.
6. **Permits.** An optional permit (e.g. SRR sector 198) bypasses only
   `no_parking_except_permit` rules for that sector — never any other rule.

Rules are evaluated per block (one curb side = one segment = one colour),
not per exact meter, in v1.

## Stack

- **App:** Flutter (iOS + Android)
- **Backend:** ASP.NET Core
- **Database:** PostgreSQL + PostGIS
- **API (planned):** `GET /api/curbs?bbox=&at=&permit=`,
  `GET /api/curbs/at?lat=&lon=&at=&permit=`, `GET /api/data-status`
  — both evaluator endpoints call the same evaluator, so answers never
  disagree.

## Data

- **Signs:** Ville de Montréal open data, *Stationnement sur rue —
  signalisation courante* (~144,690 signs, 1,546 codes). City sign
  coordinates are approximate and the dataset can lag behind the street,
  which is one more reason unknown exists.
- **Curbs:** Ville de Montréal *Géobase double* (~91,606 curb sides).
- **Sign text reference:** the December 2015 *Catalogue de signalisation*
  (backup only — the city's own sign descriptions come first).
- **Dictionary:** every code's rule is reviewed before it reaches the app.
  Unreviewed codes → unknown. Nothing ships on an unreviewed guess.

## Project status

| Piece | State |
| ----- | ----- |
| Database schema (7 tables) | ✅ Done |
| Curbs loaded (~91,606 sides) | ✅ Done |
| Signs loaded + linked to curbs (114,426 links) | ✅ Done |
| Reviewed rules | 🔄 195 of 1,546 codes loaded, growing |
| Evaluator (the decision logic) | 🔄 In progress, built piece by piece |
| API | 📋 Spec'd, not built yet |
| App UI (Flutter) | 📋 Not started — starts only after evaluator tests pass |

The evaluator is built one piece at a time, each explained in plain words
with a testable example first. Its ~40 tests (bans, durations, permits,
overnight windows, unknown handling) must all pass against the real data
before any UI work.

## Key decisions (locked for v1)

- **Most-restrictive-wins.** Priority numbers pick the reason text only —
  they never change the answer.
- **Arrows ignored.** The sign arrow field (`FLECHE_PAN`) is undocumented
  and unresolved — v1 ignores it entirely.
- **Permits in the MVP.** One SRR permit zone per user, normalized
  (lowercase, strip non-alphanumerics, strip leading zeros).
- **No-data areas.** The 15 non-Montréal municipalities on the island
  (DDO, Pointe-Claire, Dorval, …) have no city sign data and are marked
  "not covered," not grey.
- **Middle-of-street taps.** If a tap is nearly equidistant from both
  sides, the app shows both lines and lets the user pick a side — it never
  silently guesses. GPS checks use nearest.
- **30 m, inclusive.** Nearest curb within 30.0 m counts; beyond that,
  unknown. Distance is measured to the whole curb line.

## Project layout (planned)

```
parksure/
├── app/        # Flutter app
├── api/        # ASP.NET Core backend + evaluator
├── db/         # Schema, ETL, dictionary SQL
└── docs/       # Blueprint, explainers, evaluator tests
```

## Getting started (in progress)

Prerequisites: PostgreSQL + PostGIS, .NET SDK, Flutter SDK.

1. Create the database and run the schema in `db/`.
2. Load curbs, then signs, then reviewed rules (in that order).
3. Run the evaluator tests — all must pass before UI work.

Setup steps will be filled in as the API and app land. Nothing here is
presented as working until it is.

## Disclaimer

ParkSure is a guide, not legal advice. City data can lag behind the
street: a sign can exist on a pole before it appears in the data, and vice
versa. Always check the physical signs before you park. If the app and the
street disagree, the street wins.

## License

TBD.
