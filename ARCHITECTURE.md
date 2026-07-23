# PremFlix Architecture

A cinematic, cross-platform Jellyfin client for Android, Android TV, Linux,
Windows, and macOS.

## Layered Clean Architecture, feature-first

```
lib/
  core/                 Shared infrastructure — no feature imports core→feature
    api/                Dio client, interceptors, Jellyfin endpoint wrappers
    models/             Domain models mapped from Jellyfin DTOs
    repositories/       Repository interfaces + implementations
    services/           Cross-cutting services (secure storage, preferences)
    theme/              Colors, typography, ThemeData, accent controller
    widgets/            Reusable design-system widgets
    utils/              Responsive helpers, formatters
    router/             go_router table + custom page transitions
  features/<name>/
    data/               Feature-specific data sources / caching
    domain/             Feature-specific entities and logic
    presentation/       Screens, widgets, Riverpod controllers
```

**Why feature-first?** Screens change together with their controllers and
widgets; grouping by feature keeps a change local to one directory. Shared
infrastructure that more than one feature needs (the Jellyfin API surface,
media models, theming) lives in `core/` — the dependency rule is strictly
`features → core`, never the reverse and never feature → feature.

**Why a repository layer?** The UI never sees Dio, HTTP paths, or Jellyfin
DTO shapes. Repositories expose domain models and hide transport, caching
(Hive), and error mapping. This makes controllers trivially testable with a
fake repository and isolates Jellyfin API changes to one layer.

## State management: Riverpod

- `Notifier`/`AsyncNotifier` for screen state; plain `Provider` for wiring.
- Services requiring async construction (Hive boxes, secure storage) are
  built in `main()` and injected via `ProviderScope` overrides — features
  receive ready dependencies and contain zero initialization code. The
  un-overridden provider throws, so a wiring mistake fails loudly at
  startup instead of silently misbehaving.

## Theming: one state change restyles the app

The palette is dark-first and fixed (`#0A0A0A` canvas, `#171717` cards);
only the accent is dynamic. `ThemeController` holds an `AccentPreset`
(persisted in Hive) and the root `MaterialApp` rebuilds its `ThemeData`
when it changes. Widgets read the accent from the theme
(`context.accent`), so no widget ever hardcodes a color. Each preset
carries a companion shade for two-tone gradients, giving every accent a
rich treatment without per-theme tuning.

Material ink/ripple is disabled globally — custom widgets provide their
own hover/press/focus feedback, which is what removes the "Material
Design feeling".

## Typography

Outfit (geometric display face) for titles and the wordmark; Inter for
body and UI labels. Negative tracking at display sizes reads like film
key art; Inter stays legible at TV viewing distances.

## Navigation: go_router with custom transitions

Routes are named constants in `AppRoutes` (single source of truth for
deep links). Every route supplies a `CustomTransitionPage` from
`AppTransitions`:

| Transition  | Used for                 | Character                          |
|-------------|--------------------------|------------------------------------|
| `fade`      | ambient moves            | quick cross-fade                   |
| `slideUp`   | modal pages (player)     | slide + fade from bottom           |
| `cinematic` | detail pages             | fade + scale + blur-under          |

`cinematic` combines with poster `Hero` animations so detail pages appear
to grow out of the tapped card. The outgoing page blurs and recedes,
adding depth.

### Tabbed shell

The five primary destinations — **Home, Movies, TV Shows, Collections,
Search** — live in a `StatefulShellRoute.indexedStack`. Each branch keeps
its own navigator and scroll position, so switching tabs is instant and
never reloads content. `PremFlixShell` renders the chrome around the
active branch and adapts to the device: a **bottom navigation bar** on
touch phones, a **floating top navigation bar** on tablets, desktop, and
TV. The bar frosts as the active page scrolls (one `ScrollNotification`
listener spans every branch), and Android back on a secondary tab returns
to Home before exiting (`PopScope`).

Detail, player, and settings routes are **siblings** of the shell, so
they use the root navigator and cover the navigation bar full-screen. The
Movies and TV pages are pure composition over one generic
`catalogRowProvider` (keyed by a `(type, kind, genre)` record), and every
rail in the app — home rows, detail "More Like This", genre rows — renders
through the single `HorizontalMediaRail`.

### TV / D-pad focus

Every interactive element (tabs, cards, icon buttons, avatar) is a
`FocusableActionDetector`, so it is reachable and activatable by a remote
with no hover dependency. Directional (arrow-key) traversal is geometry-
based, so the visual Stack layout — nav bar above content — gives natural
up/down movement between the bar and the rows. The active top-nav tab
autofocuses on TV for a deterministic initial focus, and focused cards
lift to 1.08× (vs 1.05× on pointer devices) so the indicator reads at
living-room distance.

## Responsiveness

Width-based breakpoints (`compact < 600 < medium < 905 < expanded < 1400
< large`), not platform checks — a half-width desktop window gets the
tablet layout. `ResponsiveContext` centralizes page insets and poster
sizes so every screen scales consistently. TV is detected via directional
navigation mode for d-pad focus handling.

## Networking, caching, storage

- **Dio** with interceptors: automatic Jellyfin auth header attachment,
  retry with backoff, timeout, and typed error mapping.
- **Hive** caches home rows, metadata, and search history for instant
  cold-start paint; network refreshes replace cache in the background.
- **flutter_secure_storage** holds the access token, user id, and server
  URL — credentials never touch Hive or preferences.

## Authentication & session

`SessionController` (core) is the single source of truth: `loading` =
restoring credentials (splash), `data(null)` = signed out, `data(session)`
= signed in. It lives in **core**, not the auth feature, because the Dio
client needs the token and the router needs guards — and core never
imports features. The auth feature contains only presentation (login
screen + form controller).

Flow: login form → `AuthRepository.authenticate` (POST
`/Users/AuthenticateByName` with the MediaBrowser identity header; the
server issues a **per-device token** — no admin API key ever) →
`SessionController.establish` persists to secure storage → the router's
`refreshListenable` fires → redirect to home. Sign-out reverses it, with
best-effort server-side token revocation. A 401 from any API call clears
the session, so remote revocation boots the app to login from anywhere.

`DeviceIdentityService` persists a generated device id so re-logins reuse
the same server-side device entry instead of creating ghosts.

### Onboarding: automatic server discovery

Signed-out users land on the **discovery screen**, not the login form.
`ServerDiscoveryService` scans the LAN, streaming servers into a
`Notifier` as they are found so cards pop in live. Three concurrent
methods, bounded by a ~7 s timeout:

1. **UDP broadcast** on `:7359` — Jellyfin's own client auto-discovery
   (`"who is JellyfinServer?"` → JSON reply). Primary and most reliable.
2. **mDNS** for `_jellyfin._tcp.local` — best-effort, silently skipped
   where multicast is unavailable.
3. **Subnet scan** — a gated last resort that probes
   `/System/Info/Public` across the local /24, started only if the faster
   methods find nothing during a short grace window.

Discovered servers hand a `LoginArgs(serverUrl, serverName)` to the login
screen, which then hides the address field and asks only for credentials.
Manual entry and remote servers are never removed — "Use another server" /
"Enter manually" open the same login screen with an editable address, and
`AuthRepository` is unchanged. Discovery only appears when signed out;
returning (stored-session) users route straight to home.

## Playback

**media_kit** (libmpv) — the only Flutter player with first-class Linux,
Windows, and macOS support plus full subtitle/audio-track selection,
matching the platform matrix exactly.

`PlaybackRepository` posts a deliberately permissive device profile
(mpv plays nearly everything), so the server direct-plays whenever
possible and only transcodes when forced. The native `Player` is a
1:1-with-the-screen imperative resource, so it lives in a plain
`PlayerSession` class owned by the screen state — Riverpod supplies
repositories, not the resource. Progress reports (start / 10-second
progress / stopped) are always best-effort: a dropped report never
interrupts playback.

**Cross-screen sync**: `libraryRefreshTickProvider` (core) bumps when
playback ends. Resume-sensitive providers watch it and refetch past the
cache TTL — Continue Watching, detail pages, and episode lists update
without any feature importing another feature.

## Search

Debounced (350 ms) with generation counting — a slow response for "bat"
can never overwrite results for "batman". Previous results stay on
screen during a query (a hairline progress bar signals activity) instead
of flashing skeletons on every keystroke. Recent searches persist in
preferences; a term earns a history slot when the user opens one of its
results, not merely by being typed.

