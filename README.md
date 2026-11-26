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

### Invite links

The canonical invite link, for QR codes and anything the admin console
prints or shares, is:

```text
https://buspilot.org/join#code=<code>
```

- The code is in the fragment (`#…`), which browsers never send to a
  server, so it does not end up in web server or proxy logs when the app is
  not installed and the link opens in a browser.
- `buspilot.org` is the host the app links are verified for (Android App
  Links: `/.well-known/assetlinks.json`; iOS Universal Links later), so the
  link opens the app directly.

The app also accepts, typed, scanned or opened:

- `https://buspilot.org/join/<code>` (the first format; the code reaches the
  server in the path);
- `https://app.buspilot.org/join#code=<code>`, the admin console's current
  default (`NUXT_PUBLIC_RIDER_JOIN_URL`). Scanned in the app it works; scanned
  with the phone's camera it opens the admin console's host, which is not an
  app link host. **The admin console should use
  `NUXT_PUBLIC_RIDER_JOIN_URL=https://buspilot.org/join#code={code}`.**

Try a link on Android with:

```bash
adb shell am start -a android.intent.action.VIEW -d 'https://buspilot.org/join#code=DEMO-KOBE-2026' org.buspilot.buspilot_rider
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
| `lib/src/push/` | Push: token registration, notification channels and alert messages (`PushAlert`); FCM on Android (`FcmPushService`), nothing elsewhere (`NoPushService`) |
| `tool/` | Development scripts |

**State management:** one `ChangeNotifier` (`AppState`) provided through an
`InheritedNotifier` (`AppScope`). The app has one shared state (what the device
may see, plus today's trips) and a handful of screens, so no framework is
needed; screens keep their own form state.

**Data:** row-level security decides what the anonymous device sees. The app
reads its routes through `rpc/my_routes` (routes of joined operators plus
followed routes, with the same embeds as `route`; a public route opened from a
link is read from `route` by id), service days through `rpc/service_days`
(national holidays applied on the server) and holiday names from
`national_holiday`, for about 13 months from this month, plus
`service_calendar`, `post` (general posts are members-only on the server) and
the device's memberships and subscriptions. All of it is cached as JSON for
offline use. Stop locations come only from the `stop_location` view: at map
level all stops, for arrival-times-only audiences the first two followed stops
per operator (the mini map), else none.

**Live data:** trip progress, stop states and ETAs (`trip_instance`,
`stop_event`, and live trips with their planned stops, `trip_instance_stop`)
are polled every 30 seconds while a screen is open, behind the `LiveSource`
interface. They will come from the engine's Live API instead, not from
Supabase Realtime.

**Push:** Android uses Firebase project `buspilot-84a51` (`android/app/google-services.json`,
`lib/firebase_options.dart`: public identifiers). After the user follows a stop
and agrees, the app asks for notification permission and stores its Firebase
Installation ID (firebase_messaging 17 `register()` / `onRegistered`) in
`device.push_token`; the engine sends to it. Without Firebase (iOS for now, or
if it fails to start) the app works without push.

The engine's messages are described in buspilot-org/server
`engine/README.md` ("Push message format"). The app:

- creates the Android channels `arrival_alerts` and `trip_changes`, named in
  the app's language (`MainActivity.kt`);
- shows an alert that arrives in the foreground in a snack bar, with a button
  to the stop;
- opens the route (or live trip) at the stop and trip of a tapped
  notification, also when the notification started the app;
- keeps `device.language` current (the server writes the text in it) and
  registers again when the engine cleared an invalid `push_token`;
- ignores messages with a `v` other than `1` and unknown `kind` values.

**Branding:** operator logos and cover images (`branding.logo_url`,
`cover_url`) load only from the operator's folder in the `operator-branding`
bucket on the app's own Supabase host, so riders' phones never contact a host
an operator picked.

## Contributing

Every pull request gets at least one thorough self-review before merge; see the [Buspilot agent policy](https://github.com/buspilot-org/.github/blob/main/docs/agent-policy.md).

## License

[GNU Affero General Public License v3.0](LICENSE)

The brand colour tokens in `lib/src/ui/brand/` come from the `buspilot-org/brand` repository and are covered by this licence too. "Buspilot", バスパイロット and the Arrival logo are used as trademarks of the Buspilot service; this licence grants no right to use them. The name, logo, app icons and map markers and the symbol (`assets/markers/`, `assets/brand/`, the launcher icons under `android/app/src/main/res/mipmap-*` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/`) are all rights reserved; forks must replace them with their own. The M PLUS Rounded 1c font in `assets/fonts/` is licensed under the [SIL Open Font License 1.1](assets/fonts/OFL.txt).
