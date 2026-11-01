# 🚀 Astra — Building & Sideloading the `.ipa` from a PC

This guide takes an **Astra source tree on a Windows/Linux PC** all the way to
an **iPhone** with zero paid Apple tooling. It uses:

| Stage | Tool | Where it runs |
|---|---|---|
| 1. Dev & test loop | Flutter SDK | your PC (`flutter run` releases an **Android APK**, or run on Windows/Linux desktop to preview UI) |
| 2. Compile for iOS | GitHub Actions (free `macos-latest` runner) | cloud **Mac** — required, only Apple builds iOS binaries |
| 3. Sign the `.ipa` | **AltStore** or **Sideloadly** (free Apple ID) | your PC |
| 4. Install + auto-renew | AltStore / AltServer | your PC ⇄ iPhone on Wi-Fi |

> **Why a Mac runner anyway?** Xcode/iOS toolchain only exists on macOS, so the
> *compilation* must happen on one. GitHub gives every account free macOS CI
> minutes, so you never need to own a Mac. **Signing**, however, can be done on
> a PC — that's what AltStore/Sideloadly do.

---

## Stage 0 — One-time setup (your PC, ~20 min)

1. **Install the Flutter SDK** (<https://docs.flutter.dev/get-started/install>)
   and make sure `flutter --version` runs. 3.24+ is required by `pubspec.yaml`.
2. **Install Git** and clone your copy of the Astra repo:
   ```bash
   git clone <your-repo-url> astra && cd astra
   ```
3. **Generate the platform folders** — they are intentionally not committed so
   the repo stays machine-independent:
   ```bash
   flutter create --org com.astra --project-name astra .
   ```
   This creates `ios/`, `android/`, `linux/`, `web/` shells and wires everything up.
4. **Add background audio to the iOS shell** (once per generated `ios/Runner/Info.plist`):
   ```xml
   <key>UIBackgroundModes</key>
   <array>
     <string>audio</string>
   </array>
   ```
   Insert it anywhere inside the top-level `<dict>`. This is what allows music
   to keep playing while the app is minimized. *(The GitHub Actions workflow
   adds this automatically at Step 5 with PlistBuddy, so you can skip it locally.)*
5. **Test-drive on your PC first** (highly recommended):
   ```bash
   flutter pub get
   flutter run            # Android device/emulator, or
   flutter run -d windows # or -d linux
   ```
   Verify: Home loads, search returns results, a track plays, background play
   works, lock-screen controls appear (Android). All UI logic is identical on
   iOS; only the build machine differs.

---

## Stage 1 — Compile the iOS build on GitHub Actions (free, ~15 min)

1. Push this project to **your own GitHub repository**:
   ```bash
   git init && git add . && git commit -m "Astra"
   git remote add origin https://github.com/<you>/astra.git
   git push -u origin main
   ```
2. In the repo, open the **Actions** tab → select **“Build iOS (.ipa)”** →
   press **Run workflow** (it also runs automatically when you push a `v*` tag).
3. When it succeeds, download the artifact **`Astra-unsigned-ipa`** from the
   run page. You now have **`Astra.ipa`** — unsigned but fully built.

Notes:
- Free accounts get 2,000 CI minutes/month; each run ≈ 10–15 macOS minutes
  (~5x multiplier on macOS ⇒ ~50–75 accounted minutes, still comfortably
  within the free tier for a few builds a month).
- If the *Analyze* step fails, fix the reported Dart issues locally
  (`flutter analyze`) and push again.

---

## Stage 2 — Signing & installing (two supported routes)

### Route A — AltStore (recommended: auto-renews for you)

1. On your PC (Windows: install **iTunes** from Apple's site *and* **iCloud**
   first — both are needed for USB pairing — then install **AltServer** from
   <https://altstore.io>).
2. Sign in **AltServer** with your free Apple ID.
3. On the iPhone: Settings → General → VPN & *Device Management* not needed
   here; just enable **Wi-Fi sync** in the AltStore app later.
4. **Sideload the .ipa via AltServer**: right-click the tray icon →
   `AltStore` → `Install Apple ID` … or simpler: install **AltStore on the
   iPhone first** (Sideload AltStore.ipa with Sideloadly—see Route B—or use
   AltServer's one-click install), then inside AltStore:
   - Click **`+`** → choose the downloaded **`Astra.ipa`**
   - Sign in with the **same free Apple ID**
   - AltStore signs the app with your Apple ID and installs it.
5. First launch: allow it in **Settings → General → VPN & Device Management →
   your Apple ID → Trust**.
6. **Keep it alive**: AltStore re-signs Astra automatically every 7 days while
   your PC and iPhone are on the same Wi-Fi (AltServer running).

> Limits with a free Apple ID: app expires after **7 days** (auto-renewed by
> AltStore), max **3 apps**, max **2 devices**. A paid Apple Developer Program
> account ($99/yr) removes the expiry — everything else in this guide is
> unchanged.

### Route B — Sideloadly (simplest one-shot manual signing)

1. Install **Sideloadly** on Windows/Linux from <https://sideloadly.io>.
2. Connect your iPhone by USB (Windows: iTunes must be installed once for the
   drivers).
3. Drag **`Astra.ipa`** into the window.
4. Enter your free **Apple ID** (leave orientation/resign options default
   — Sideloadly handles framework re-signing for you).
5. Click **Start** → wait → **Astra appears on your phone**.
6. Trust the developer profile (Settings → General → VPN & Device Management).
7. Re-sign every 7 days by repeating steps 3–5 (Sideloadly can cache your
   Apple ID and re-sign with one click).

### Optional — a “real” release build with paid signing

With a paid Apple Developer account you can even skip PC-side signing by
building a *signed* ipa directly on a Mac CI runner:

```yaml
# .github/workflows/build-ios-signed.yml (only for paid accounts)
- run: flutter build ipa --release --export-options-plist ios/ExportOptions.plist
```

…after storing a temporary **App Store Connect API key** in repo secrets
(`App_Store_Distribution` provision profile). Not required for personal use.

---

## Stage 3 — Using Astra on the iPhone

1. Launch **Astra** — Home shows trending + the YouTube Music feed.
2. Search anything, then tap a song card. Playback starts and the mini player
   appears above the tab bar.
3. Tap the mini player (or queue button) for the full-screen player —
   artwork-tinted, repeat/shuffle/seek, queue.
4. Heart a track or add it to any playlist in the **Library** tab — data is
   stored locally on the device.
5. Minimize the app: audio continues; lock-screen shows artwork + controls.
6. Swipe up/killed app state is fully supported by `audio_service` for iOS
   lock-screen controls.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter analyze` errors in CI | Run locally and fix; CI runs the same SDK |
| Audio stops when minimized | `UIBackgroundModes: audio` missing from `Info.plist` (Stage 0 step 4 / workflow step) |
| Playback error “could not resolve stream” | Free resolvers rate-limit; try again later or add working Piped instances in `lib/core/api_constants.dart` |
| Sideloadly says “insufficient permissions” | Install/launch iTunes once on Windows, accept the trust dialog on the phone |
| App won't open after install | Settings → General → VPN & Device Management → Trust your Apple ID |
| 7-day expiry | Re-sign with Sideloadly, or let AltStore auto-renew; paid account removes it entirely |

---

## Legal

Astra streams from public YouTube Music endpoints (InnerTube) and community
Piped/Invidious instances and stores no keys or accounts. Respect YouTube's
Terms of Service and your local laws; this software is for personal use.
