# Brick Crusher

The Mason's Workshop edition — a pseudo-3D arcade brick-breaker by WAJIHA.

- **Package:** `com.gameswajiha.brickcrusher`
- **Engine:** Flutter/Dart, portrait.
- **Modes:** Campaign (5 levels), Endless, Score Attack (2 min) × 4 difficulty tiers (Chill, Classic, Wild, Insane).
- **Engine-owned state machine** (`lib/engine/crusher_engine.dart`) with a watchdog — stuck states impossible by construction. See `RULES.md` (the authoritative rules, 13 sections).
- **Audio:** fully synthesized + cached, busy-guarded music state machine, pause/resume on lifecycle, prewarmed on splash. Menu music, gameplay BGM, all SFX, toggles + volume.
- **Profile:** persisted as one order-preserving JSON string (`brickcrusher_player_names_json`) — never `setStringList`. Saved on every keystroke, committed on focus loss.
- **Customization:** 14 physical-material themes + custom theme creator (PRO), 8 paddle / 8 ball / 8 brick styles.
- **PRO:** real `in_app_purchase` — `brickcrusherpro` (one-time), `brickcrushercoffee`, `brickcrusherchocolate` (consumable tips). Free-vs-Pro screen; graceful when products aren't configured in Play Console yet.
- **Share:** `share_plus` with the real Play URL. **Review:** `in_app_review` with store fallback.

## Build

```sh
flutter pub get
flutter analyze
flutter build apk --release
flutter build appbundle --release
```

Release signing comes from repo secrets (`UPLOAD_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) via `.github/workflows/build.yml`.
