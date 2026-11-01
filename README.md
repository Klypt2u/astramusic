# Astra 🎵

A minimalist, **completely ad-free** music streaming app for iOS — inspired by
Lyra's clean layout (dark theme, smooth bottom navigation, artwork-first
cards, dynamic color accents) — powered entirely by free, key-less YouTube
Music endpoints.

Built with **Flutter**, so the entire codebase develops on a **Windows/Linux
PC**; iOS `.ipa` packaging happens via GitHub Actions (free macOS runner) +
AltStore/Sideloadly. **[Full build & sideload guide →](docs/BUILD_IPA_GUIDE.md)**

---

## Features

- ** Completely ad-free** — playback uses direct stream URLs, no ad breaks,
  no SDK trackers, no accounts.
- **Home** — personalized recommendations (YouTube Music home feed), trending
  charts, recent albums — animated artwork shelves with shimmer loading.
- **Search** — instant, debounced search across **Songs / Albums / Artists /
  Playlists** with autocomplete suggestions and infinite pagination.
- **Now Playing** — immersive full-screen player: huge artwork, gradient
  background **extracted from the album art** (PaletteGenerator), seek bar,
  repeat (one/all), shuffle, queue sheet.
- **Background audio** — `audio_service`-backed playback continues under the
  lock screen/notification center with artwork + transport controls.
- **Library** — liked songs (♥ anywhere) and custom playlists, saved in local
  storage; play/shuffle/remove/reorder async-safe.
- **Mini player** — persistent above the tab bar; tap to expand.

---

## How the free backend works (no API keys)

`lib/services/` implements a compact **InnerTube client** — the private,
publicly-documented API that YouTube Music's own web player uses:

```
search ─────────────► /youtubei/v1/search             (WEB_REMIX client)
home + charts ──────► /youtubei/v1/browse             FEmusic_home / FEmusic_charts
album/artist ───────► /youtubei/v1/browse             MPREb…/UC…/VL…
suggestions ────────► /youtubei/v1/music/get_search_suggestions
audio stream ───────► /youtubei/v1/player             IOS client → plain URLs,
                          then fallback: public Piped / Invidious instances
```

Because the **iOS InnerTube client** returns *unscrambled* media URLs, Astra
needs no signature deciphering. If that call is ever blocked, the
`PipedService` fallback rotates through public Piped/Invidious instances and
blacklists dead ones for the session. `lib/core/api_constants.dart` is the
single place to add/rotate instances.

---

## Project structure

```
astra/
├── pubspec.yaml                     # deps & metadata
├── analysis_options.yaml
├── .github/workflows/build-ios.yml  # CI → unsigned .ipa (macOS runner)
├── docs/
│   └── BUILD_IPA_GUIDE.md           # PC → iPhone .ipa instructions
└── lib/
    ├── main.dart                    # bootstrap: audio session, audio_service, DI
    ├── core/
    │   ├── theme.dart               # design tokens (Lyra-style dark theme)
    │   └── api_constants.dart       # InnerTube endpoints, params, instances
    ├── models/
    │   └── media.dart               # Track / Collection / UserPlaylist (+JSON)
    ├── services/
    │   ├── yt_music_service.dart    # InnerTube client + JSON parsers
    │   ├── piped_service.dart       # Piped/Invidious stream fallback
    │   ├── audio_handler.dart       # background audio (audio_service + just_audio)
    │   └── library_storage.dart     # favorites/playlists persistence
    ├── state/
    │   ├── player_provider.dart     # playback state → UI (ChangeNotifier)
    │   └── library_provider.dart    # favorites/playlists logic
    ├── widgets/
    │   ├── media_art.dart           # cached artwork + shimmer
    │   ├── album_card.dart          # shelf cards (album/artist)
    │   ├── shelf.dart               # horizontal shelf + placeholders
    │   ├── track_tile.dart          # track row (favorite, add-to-playlist)
    │   └── mini_player.dart         # mini player + transport controls
    └── screens/
        ├── root_shell.dart          # bottom nav shell
        ├── home_screen.dart         # recommendations + charts
        ├── search_screen.dart       # instant search
        ├── library_screen.dart      # playlists + liked songs
        ├── collection_screen.dart   # album/artist/playlist detail + local lists
        └── now_playing_screen.dart  # immersive player
```

**Separation of concerns:** `services` own networking/persistence/audio,
`state` owns reactive app state (Provider `ChangeNotifier`s), `screens`/`widgets`
own pure UI — widgets never touch HTTP directly.

---

## Quick start (PC)

```bash
flutter --version          # Flutter 3.24+ / Dart 3.5+
git clone <repo> && cd astra
flutter create --org com.astra --project-name astra .   # generate platform shells
flutter pub get
flutter run                # Android device/emulator, or -d windows / -d linux
```

> `flutter create` re-generates the per-machine platform folders (they are
> git-ignored), and the guide's one extra step adds `UIBackgroundModes: audio`
> for iOS background playback. **CI does that patch automatically.**

### iOS `.ipa` packaging

See **[docs/BUILD_IPA_GUIDE.md](docs/BUILD_IPA_GUIDE.md)** — GitHub Actions
build (free) then AltStore/Sideloadly signing with a free Apple ID.

---

## Libraries used

| Pub package | Role |
|---|---|
| `provider` | state management |
| `http` | InnerTube / Piped / Invidious calls |
| `just_audio` | audio playback engine |
| `audio_service` | background audio + lock-screen controls |
| `audio_session` | interruption handling / audio focus |
| `shared_preferences` | local library persistence |
| `cached_network_image` | artwork caching |
| `palette_generator` | dynamic accent color from artwork |
| `shimmer` | loading placeholders |

---

## Notes & limitations

- **Filter param drift:** InnerTube protobuf search-params occasionally change
  upstream; they're defined in one place (`kSearchFilterParams`) matching what
  `ytmusicapi` computes — refresh from upstream if search filters ever act odd.
- **Fallback instances** are community-run; rotation handles outages. Add your
  own Piped/Invidious instance for reliability.
- **Artist pages:** show top songs via `videos` filter parse; a few niche
  shelves may be skipped silently (parser is defensive by design).
- **Legal:** personal-use software; respect YouTube's ToS. No keys, no ads,
  no tracking, ever.
