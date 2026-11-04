# ParkSure app (Flutter)

The iOS + Android client for the ParkSure API.

## Layout

```text
lib/
├── main.dart          ← app start, wrapped in ProviderScope
├── models/            ← plain Dart classes: Curb, Verdict
├── data/              ← parking_repository.dart (the API calls)
├── providers/         ← Riverpod providers (the app's memory)
├── screens/           ← full pages, e.g. the map screen
└── widgets/           ← smaller reusable pieces, e.g. the result sheet
```

Data flows one way: **screen → provider → repository → API**. Widgets never call
`http` directly, and models never know about Flutter.

| File | Role |
| ---- | ---- |
| `models/verdict.dart` | `/api/curbs/at` answer (`Verdict`, `ParkingStatus`, `Sign`, `CurbCandidate`) |
| `models/curb.dart` | `/api/curbs?bbox=` GeoJSON features (`Curb`, `CurbMap`) |
| `data/parking_repository.dart` | the only HTTP code; `checkAt()` and `curbsInView()` |
| `providers/parking_providers.dart` | permit, query time, viewport, pin, and the two `FutureProvider`s |
| `screens/map_screen.dart` | map, coloured curbs, tap-to-check |
| `widgets/verdict_sheet.dart` | result panel, including the "which side?" picker |
| `widgets/status_style.dart` | colour / label / icon per status |

Zero false green holds here too: any status string the app doesn't recognise
parses as `unknown`.

## Run

Start the API (`dotnet run --project ParkSure.Api`, listens on `http://localhost:5277`), then:

```bash
# Android emulator (default base URL is http://10.0.2.2:5277)
flutter run

# iOS simulator
flutter run --dart-define=API_BASE_URL=http://localhost:5277
```

## Test

```bash
flutter analyze
flutter test
```
