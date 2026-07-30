# Design System Néon — WIWIGA

## Palette de Couleurs

Toute couleur DOIT provenir de `NeonColors`. Jamais de `Colors.*` ou hex hardcodé.

| Token | Hex | Usage |
|-------|-----|-------|
| `NeonColors.primary` | `#2DD4BF` | Vert émeraude — actions principales, glow |
| `NeonColors.secondary` | `#F59E0B` | Orange/doré — accents, tours de jeu |
| `NeonColors.accent` | `#00D9FF` | Cyan — effets, sommes, highlights |
| `NeonColors.background` | `#1E293B` | Fond principal |
| `NeonColors.surface` | `#0F172A` | Fond des cartes, inputs |
| `NeonColors.card` | `#1E293B` | Fond des cards |
| `NeonColors.border` | `#334155` | Bordures neutres |
| `NeonColors.success` | `#10B981` | Victoires, gains, confirmations |
| `NeonColors.warning` | `#F59E0B` | Alertes, égalités |
| `NeonColors.error` | `#EF4444` | Erreurs, pertes, dangers |
| `NeonColors.textPrimary` | `#F8FAFC` | Texte principal |
| `NeonColors.textSecondary` | `#94A3B8` | Texte secondaire |

## Effets Glow

```dart
// Glow standard (boutons, bordures actives)
BoxShadow(
  color: NeonColors.primary.withOpacity(0.3),
  blurRadius: 8,
)

// Glow intense (focus, sélection)
BoxShadow(
  color: NeonColors.primary.withOpacity(0.5),
  blurRadius: 16,
  spreadRadius: 2,
)

// Glow pulse (badges, notifications)
// Utiliser AnimationController + opacity oscillante 0.2 → 0.6
```

## Typographie

- **Titres** : Orbitron (via `google_fonts`) — style gaming/futuriste
- **Corps** : Inter (via `google_fonts`) — lisible et professionnel
- **Tailles** :
  - H1 : 36px bold (Orbitron)
  - H2 : 28px bold (Orbitron)
  - H3 : 24px semi-bold (Inter)
  - Body : 16px regular (Inter)
  - Caption : 12px regular (Inter)
  - Small : 10px (Inter)

## Composants Obligatoires

### NeonButton
```dart
NeonButton(
  text: 'Lancer les dés',
  onPressed: _rollDice,
  variant: NeonButtonVariant.primary, // primary | secondary | outline
  icon: Icons.casino,
)
```

### NeonCard
```dart
NeonCard(
  child: Row(...), // Contenu avec padding automatique
)
```

### NeonInput
```dart
NeonInput(
  label: 'Montant',
  onChanged: (v) => ...,
  glowOnFocus: true,
)
```

## Règles Visuelles

1. **Fonds sombres uniquement** : background `#1E293B` ou surface `#0F172A`
2. **Glow = feedback** : glow uniquement sur éléments interactifs (hover, focus, actif)
3. **Pas de gradients** : couleurs plates avec glow, pas de `LinearGradient`
4. **Border radius** : 12px pour cards, 8px pour boutons, 20px pour badges/pills
5. **Animations** : 200-300ms pour transitions, `Curves.easeInOut` standard
6. **Ombres** : glow uniquement (pas de `BoxShadow` noir classique)
7. **Espacement** : multiples de 4px (4, 8, 12, 16, 20, 24, 32)

## Assets Visuels

- **Icônes** : `font_awesome_flutter` + SVG custom
- **Animations** : Lottie pour victoires (lottiefiles.com)
- **Rangs** : Bronze `#CD7F32`, Argent `#C0C0C0`, Or `#FFD700`, Platine `#E5E4E2`, Diamant `#B9F2FF`
- **Paiements** : MTN `#FFCC00`, Orange `#FF6600`
