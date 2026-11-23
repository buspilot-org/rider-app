# Buspilot rider app

App for parents, students and passengers of [Buspilot](https://buspilot.org), a bus tracking service for privately operated buses (schools, kindergartens, driving schools, hotel shuttles, sports clubs).

- Know when the bus comes: arrival times for your stops, alerts a few minutes before the bus arrives.
- One place for everything about the bus: today's status, cancellations, delays, announcements, service calendar.
- No account and no personal data: join an operator with an invite code or QR code. The app asks for no location permission; alerts are computed on the server.

iOS and Android. The backend is [buspilot-org/server](https://github.com/buspilot-org/server) (Supabase).

## Development

The app talks to a Supabase project. For development, run the local stack of
[buspilot-org/server](https://github.com/buspilot-org/server) (`npx supabase start`
in its clone) and put its URL and publishable key in `config/local.json`
(git-ignored), starting from `config/example.json`:

```json
{
  "SUPABASE_URL": "http://127.0.0.1:55321",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_…",
  "MAP_STYLE_URL": ""
}
```

`MAP_STYLE_URL` is a MapLibre style. Empty means no map: the app then shows
arrival times only, which is all most audiences may see anyway. Any style
without a key works for development, for example
`https://tiles.openfreemap.org/styles/liberty` (the tile provider for
production is still open).

```bash
flutter pub get
flutter run --dart-define-from-file=config/local.json
```

On a phone or emulator, forward the local API port first; debug builds allow
plain HTTP to 127.0.0.1 and 10.0.2.2 only:

```bash
adb reverse tcp:55321 tcp:55321
```

The seed has the demo invite code `DEMO-KOBE-2026`. Until the engine fills
`trip_instance` and `stop_event`, fake live trips (one on its way and late, one
planned, one cancelled) can be written into the **local** database:

```bash
tool/fake_live_trips.sh          # arrival times only (seed default)
tool/fake_live_trips.sh --map    # route A visible on the map too
tool/fake_live_trips.sh --clean
```

Invite links (`https://buspilot.org/join/<code>`) can be tried on Android with:

```bash
adb shell am start -a android.intent.action.VIEW -d https://buspilot.org/join/DEMO-KOBE-2026 org.buspilot.buspilot_rider
```

## Tests

```bash
flutter analyze
flutter test
```

Widget tests run against an in-memory backend (`test/fakes/`). The integration
test joins with the demo code, follows a stop and checks home, against the
local stack; it needs a device or emulator:

```bash
flutter test integration_test -d <device> --dart-define-from-file=config/local.json
```

## Code layout

| Folder | Content |
|---|---|
| `lib/src/data/` | Read models over the PostgREST JSON, the `BuspilotApi` interface and its Supabase implementation, next-arrival logic (`arrivals.dart`) |
| `lib/src/state/` | `AppState` and the on-phone store (settings, offline cache) |
| `lib/src/ui/` | Screens: language, join and QR scan, home, route and map, alert settings, news, calendar, settings |
| `lib/src/l10n/` | Translations (ARB, ja/en/de) and the generated localisations |
| `lib/src/push/` | Push token registration: FCM on Android (`FcmPushService`), nothing elsewhere (`NoPushService`) |
| `tool/` | Development scripts |

**State management:** one `ChangeNotifier` (`AppState`) provided through an
`InheritedNotifier` (`AppScope`). The app has one shared state (what the device
may see, plus today's trips) and a handful of screens, so no framework is
needed; screens keep their own form state.

**Data:** row-level security decides what the anonymous device sees, so the app
reads whole tables (`route` with patterns, stops and trips, `service_calendar`,
`post`, …) and caches the JSON for offline use. Live state (`trip_instance`,
`stop_event`) is polled every 30 seconds while a screen is open; Realtime comes
later. Stop locations come only from the `stop_location` view.

**Push:** Android uses Firebase project `buspilot-84a51` (`android/app/google-services.json`,
`lib/firebase_options.dart`: public identifiers). After the user follows a stop
and agrees, the app asks for notification permission and stores its Firebase
Installation ID (firebase_messaging 17 `register()` / `onRegistered`) in
`device.push_token`; the engine sends to it. Without Firebase (iOS for now, or
if it fails to start) the app works without push.

## Contributing

Every pull request gets at least one thorough self-review before merge; see the [Buspilot agent policy](https://github.com/buspilot-org/.github/blob/main/docs/agent-policy.md).

## License

[GNU Affero General Public License v3.0](LICENSE)
