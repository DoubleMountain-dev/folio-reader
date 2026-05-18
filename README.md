<div align="center">

# 📖 Folio Reader

**A cross-platform e-book reader built with Flutter — runs in the browser and on Android.**

[![Live Demo](https://img.shields.io/badge/Live_Demo-Try_Now-C0392B?style=for-the-badge)](https://DoubleMountain-dev.github.io/folio-reader/)
[![Landing Page](https://img.shields.io/badge/Landing_Page-Visit-2C1810?style=for-the-badge)](https://DoubleMountain-dev.github.io/folio/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

</div>

---

## What it is

Folio Reader is a feature-rich e-book reader that supports EPUB, FB2, TXT, HTML, and PDF formats. It works as a Flutter Web application hosted on GitHub Pages and as an Android application ready for the Google Play Store — the same codebase compiles to both targets through a platform abstraction layer.

---

## Built with

- **Language:** Dart
- **Framework:** Flutter (3.0+)
- **State management:** Provider
- **PDF rendering:** pdfrx (PDFium-based)
- **Audio:** audioplayers
- **Text-to-Speech:** flutter_tts (Web Speech API on web, native TTS on Android)
- **Parsing:** xml, archive, html
- **Fonts:** google_fonts (Playfair Display, DM Sans)
- **Storage:** shared_preferences
- **File I/O:** file_picker, path_provider, share_plus

---

## Technical features

- **Paged reading engine** — text is measured with `TextPainter` and split into fixed-size pages that fit the screen, matching ReadEra's UX (no infinite scroll)
- **Cross-platform architecture** — single codebase with conditional imports (`platform_io_web.dart` / `platform_io_mobile.dart`) for web and Android
- **In-app PDF reader** — built on PDFium via the `pdfrx` package; supports full-text search, dark mode (via color inversion matrix), page navigation, and bookmarks
- **EPUB parser** — extracts metadata, cover image, full chapter text, and genre from `<meta name="cover">` (EPUB 2) and `properties="cover-image"` (EPUB 3)
- **FB2 parser** — XML-based parser extracting title, author, genre, and full chapter text
- **Custom font loading at runtime** — user uploads a `.ttf` file, which is registered via `FontLoader` and persisted as base64 in SharedPreferences
- **Dictionary integration** — single-word selection triggers a fetch to the Free Dictionary API
- **Wikipedia integration** — text selection triggers a fetch to the Wikipedia REST API with title, description, and extract
- **TTS with rate control** — uses `flutter_tts` which proxies to the browser's Web Speech API on web and native Android TTS on mobile
- **Backup / restore** — full library state (books, progress, quotes, bookmarks, collections, achievements, sessions) is exported as JSON via `Blob` download (web) or share sheet (Android)
- **Reading statistics** — per-day / week / month / year aggregation, streak tracking, reading goal progress, 12 unlockable achievements
- **Year Wrapped** — Spotify Wrapped-style annual carousel report with 8 animated slides
- **Sound effects** — paper rustle / soft click page turns, UI sounds for bookmarks / quotes / achievements, looping ambient backgrounds (cafe / rain / fireplace / forest)

---

## Screenshots

<div align="center">

| Library | Reader | Statistics |
|---|---|---|
| ![Library](docs/screenshot-library.png) | ![Reader](docs/screenshot-reader.png) | ![Stats](docs/screenshot-stats.png) |

| Year Wrapped | Settings | PDF Reader |
|---|---|---|
| ![Year Wrapped](docs/screenshot-wrapped.png) | ![Settings](docs/screenshot-settings.png) | ![PDF](docs/screenshot-pdf.png) |

</div>

---

## Running locally

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.0 or newer
- For Android: Android Studio with Android SDK (API 34)
- For Web: Chrome browser
- **Important:** install Flutter to a path **without spaces** (e.g. `D:\flutter`, not `D:\Flutter SDK\`) — paths with spaces break native asset compilation

### Setup

```bash
# Clone the repository
git clone https://github.com/DoubleMountain-dev/folio-reader.git
cd folio-reader

# Install dependencies
flutter pub get

# Verify your environment
flutter doctor
```

### Run on web

```bash
flutter run -d chrome
```

The app will open in Chrome on `localhost`.

### Run on Android

```bash
# With a device connected via USB (USB debugging enabled) or an emulator running
flutter run -d android
```

### Build for production

**Web** (deploys to GitHub Pages):
```bash
flutter build web --release --base-href "/folio-reader/"
```
Output: `build/web/` — push this to the `gh-pages` branch.

**Android APK** (for testing):
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**Android App Bundle** (for Google Play):
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

See [ANDROID_BUILD.md](ANDROID_BUILD.md) for full Android build, signing, and Play Store publishing instructions.

---

## Project structure

```
folio_reader/
├── lib/
│   ├── main.dart
│   ├── models/                  # BookDocument, Achievement, ReadingSettings, etc.
│   ├── parsers/                 # EPUB, FB2, TXT, HTML parsers
│   ├── platform/                # Web/Android abstraction layer
│   │   ├── platform_io.dart
│   │   ├── platform_io_web.dart
│   │   └── platform_io_mobile.dart
│   ├── providers/               # LibraryProvider (state management)
│   ├── screens/                 # Library, Reader, Stats, Settings, Year Wrapped
│   ├── services/                # Sound, TTS, Wikipedia, Font loader
│   └── utils/                   # Theme, colors
├── assets/sounds/               # Page turn / UI / ambience sounds
├── android/                     # Android build configuration
├── web/                         # Web entry point + PWA manifest
└── pubspec.yaml
```

---



## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## Author

**DoubleMountain**
- GitHub: [@DoubleMountain-dev](https://github.com/DoubleMountain-dev)
- Email: mikstron1@gmail.com

---

<div align="center">
<sub>Made with Flutter • 2026</sub>
</div>
