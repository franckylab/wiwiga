# WIWIGA Logo Q — CADRE GRAS

**Choix validé : Q** — cadre hairline 1.2 + W plein (28/08/2026)

## Variantes
- **Glyph sans cadre** (`withFrame: false`) — W plein fin `M20 36 L32 68 …` stroke 6.2% (11% à 16px) — header, favicon 16/32/48
- **Cadre avec** (`withFrame: true`) — squircle `x11 y11 w78 h78 rx24` stroke 1.2% + W `M22 36 L33 67 …` stroke 4.8% — PWA 192/512, stores

## Fichiers générés
- `wiwiga-q-glyph.svg` / `wiwiga-q-glyph-1024.png` — sans cadre master
- `wiwiga-q-cadre.svg` / `wiwiga-q-cadre-1024.png` — avec cadre master
- `favicon.svg` (adaptatif dark/light via @media)
- `android-chrome-*.png` / `apple-touch-icon.png` (180 opaque)

## Usage Flutter
```dart
WiwigaLogo(variant: LogoVariant.icon, size: 32) // sans cadre header
WiwigaLogo(variant: LogoVariant.icon, size: 48, withFrame: true) // avec cadre PWA
WiwigaLogo(variant: LogoVariant.full, size: 48) // icon + WIWIGA Orbitron
```

Implémentation : `lib/presentation/widgets/neon/wiwiga_logo.dart` — `_QLogoPainter`
