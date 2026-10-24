# Kreedum Construction — Court & Floor Visualiser

Android app (Flutter) where customers pick a sports court or EPDM playground
design, tap to colour each area, put their logo on it, and send it to
Kreedum for a quote.

- **9 sports courts:** badminton, basketball (indoor and outdoor), tennis, pickleball (3 versions), volleyball, running track
- **31 EPDM playground floor designs**
- **Tap-to-paint:** 22 preset shades plus a custom colour picker, undo, reset and "fill whole floor"
- **Client logo:** printed on the court banner boards, or placed anywhere on EPDM floors (drag to move, slider to resize)
- **Export:** PNG image, branded PDF proposal with a colour specification, or print
- **Enquiry:** send the design image via WhatsApp, chat on WhatsApp, call or email
- **Privacy:** no login, no database, no internet permission. Everything stays on the device.

Package name / application ID: **`com.kreedum_construction`**
(Android doesn't allow `-` in package names, so the hyphen became `_`.)

---

## 1. One-time setup

Requirements: **Flutter 3.27 or newer** (stable), Android Studio with the Android SDK, and JDK 17.

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
```bash
# macOS / Linux
./setup.sh
```

The script:
1. Runs `flutter create` to generate the Android Gradle files. Files already in this repo (manifest, `MainActivity`, `lib/`) are kept.
2. Runs `flutter pub get`.
3. Generates the launcher icons (blue rounded K) and the splash screen (navy).
4. Adds release-signing support that reads `android/key.properties`.

Then:

```bash
flutter test        # checks all 40 floor drawings parse and can be painted
flutter run         # run on a phone/emulator
```

## 2. Before publishing: fill in the real details

Edit **`lib/config/app_config.dart`**:

| Field | Used for |
|---|---|
| `whatsappNumber` | WhatsApp buttons. Digits only, with country code, e.g. `919812345678` |
| `phoneNumber` | Call button, PDF footer |
| `email` | Email button, PDF footer |
| `website` | Contact screen, PDF footer |
| `address` | Contact screen, PDF footer (optional) |

## 3. Publish to Google Play

**a) Create an upload key.** Do this once, and back up the key and passwords: losing it is painful.

```bash
keytool -genkey -v -keystore C:/Users/YOU/keys/kreedum-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**b) Point the build at the key.** Copy `android/key.properties.example` to `android/key.properties` and fill it in. Never commit or share this file.

**c) Build the App Bundle:**

```bash
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

For every later update, bump `version:` in `pubspec.yaml`, e.g. `1.0.1+2`. The number after `+` must go up each time.

**d) Set up the Play Console listing.** Ready-made assets are in `play_store/`:

- `icon_512.png`: the app icon
- `feature_graphic_1024x500.png`: the feature graphic
- `listing.md`: title, short and full description, category, and Data-safety answers
- Screenshots: take 2–8 from a phone running the app (home, a court being coloured, the PDF)
- Privacy policy: publish `PRIVACY_POLICY.md` as a page on your website and paste its URL into Play Console

## 4. Adding new floors later

1. **Drop the SVG in a folder.** Put it in `assets/floors/courts/` or `assets/floors/epdm/`. It shows up in the app automatically, titled from its file name.
2. **Optional: set a title and default colours.** Add an entry in `assets/floors/catalog.json`:
   ```json
   {"id": "futsal", "title": "Futsal Court", "asset": "assets/floors/courts/futsal.svg",
    "defaults": {"surround": "#1E6B45", "court": "#2C62E0", "boards": "#2C62E0"}}
   ```
3. **Mark the paintable areas in the SVG.** Give shapes `class="zone_<name>"`, e.g. `zone_court` or `zone_surround`. Shapes with the same name paint together, and the name becomes the chip label ("Court", "Surround"). If a drawing has no `zone_` classes, every filled shape becomes its own tappable area (this is how the EPDM designs work).
4. **Logo board (optional).** Add `<image class="logo_slot" …/>` where the client logo should go. Without one, the user can still drop a floating logo on the floor.
5. **Clean up the file.** This is recommended for files exported from Illustrator or Figma:
   ```bash
   pip install lxml pillow
   python3 tools/normalize_svg.py new.svg assets/floors/courts/new.svg --logo assets/brand/logo_slot.png
   ```
   It inlines CSS styles, removes broken references, turns masks into clip paths and shrinks embedded images.
6. **Check it.** Run `flutter test`. It fails if a drawing can't be parsed or has nothing to paint.

**New category?** Add a folder under `assets/floors/`, list it under `assets:` in `pubspec.yaml`, and add a category with that `id` to `catalog.json`.

## Project layout

```
lib/
  config/app_config.dart      company + contact details
  config/theme.dart           brand colours & fonts (from docs/STYLE_GUIDE.md)
  models/catalog.dart         loads catalog.json and auto-discovers new SVGs
  models/palette.dart         preset colour swatches
  services/floor_document.dart  SVG parsing, zones, recolouring, logo slots
  services/hit_map.dart       tap -> which area (hidden colour-coded render)
  services/export_service.dart  PNG / PDF / share / print
  services/enquiry_service.dart WhatsApp / call / e-mail
  screens/                    home (search + tabs) and the colour editor
  widgets/                    floor card, logo lockup, contact/quote sheet
assets/floors/                40 floor drawings + catalog.json
assets/brand/                 Kreedum logo, icon & splash sources
assets/fonts/                 Space Grotesk, Inter, IBM Plex Mono (OFL)
tools/normalize_svg.py        SVG clean-up for new floors
play_store/                   store icon, feature graphic, listing text
```

## Brand

These all follow `docs/STYLE_GUIDE.md`:

- **Colours:** blue `#2C62E0`, navy `#0E1A3D`, paper `#F6F8FC`, accent `#8FADFF`, and WhatsApp green `#25D366` with `#08331C` text
- **Fonts:** Space Grotesk for headings, Inter for body text, IBM Plex Mono for eyebrow labels

If you add a colour, put it in `KColors` in `lib/config/theme.dart`.
