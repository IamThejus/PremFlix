# PremFlix

A beautiful, fast, cross-platform **Jellyfin client** with a cinematic,
dark-first UI — original branding, custom widgets, and smooth animation
throughout.

## Features

- **Sign in to any Jellyfin server** — per-device token via
  `AuthenticateByName`; credentials in platform secure storage, never an
  admin API key.
- **Cinematic home** — auto-cycling hero banner (Ken Burns, backdrop
  prefetch, logo art), seven independently-loading rows (Continue
  Watching, Next Up, Trending, New Movies, New Shows, Collections,
  Favorites), shimmer skeletons, frosted collapsing app bar,
  pull-to-refresh.
- **Detail pages** — shared-element poster flight, backdrop that melts
  into the canvas, cast rail, More Like This, collection contents,
  optimistic favorite/watched toggles, Resume with time-left label.
- **Series browsing** — season chips, on-demand episode lists with
  stills, progress, and watched state.
- **Player** (media_kit / libmpv) — direct play with transcode fallback,
  custom auto-hiding controls, subtitle & audio track menus, seek bar
  with buffered range, ±10 s, keyboard shortcuts, desktop fullscreen,
  Skip Intro (Intro Skipper plugin), Next Episode with auto-advance, and
  full progress reporting so resume works across all your clients.
- **Search** — debounced real-time search with categorized rails and
  persisted recent searches.
- **Settings** — six switchable accent themes (restyles the app in one
  frame), account info, cache management.
- **Offline-friendly** — home rows serve cached data when the server is
  unreachable.
- **Responsive** — phones, tablets, desktop windows, and Android TV
  (d-pad focus treatment on every interactive element).

## Platforms

Android · Android TV · Linux · Windows · macOS

## Getting started

```sh
flutter pub get
flutter run -d linux    # or windows, macos, or an Android device
```

Sign in with your server address (e.g. `http://192.168.1.20:8096`),
username, and password.

### Linux notes

Playback uses libmpv. If video fails to start, install mpv/libmpv from
your distribution (`sudo pacman -S mpv` on Arch/Manjaro,
`sudo apt install libmpv2` on Debian/Ubuntu). Secure credential storage
uses libsecret (present on any desktop with GNOME Keyring or KWallet).

## Architecture

Clean Architecture, feature-first, Riverpod, Dio, go_router, Hive.
See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design rationale —
layering rules, the session model, caching strategy, theming, and
navigation transitions.

## Known limitations

- Picture-in-Picture is declared in the Android manifest but has no
  in-app trigger yet (requires a platform channel).
