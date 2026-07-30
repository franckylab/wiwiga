# Responsive Design — WIWIGA

## Breakpoints

| Nom | Largeur | Cible |
|-----|---------|-------|
| `xs` | 0–359px | Montres, très petits écrans |
| `sm` | 360–599px | Mobiles compacts |
| `md` | 600–899px | Mobiles grands, petites tablettes |
| `lg` | 900–1199px | Tablettes |
| `xl` | 1200–1599px | Desktop |
| `xxl` | 1600px+ | Grands écrans |

## Pattern Standard

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return _buildMobileLayout();
    } else if (constraints.maxWidth < 900) {
      return _buildTabletLayout();
    } else {
      return _buildDesktopLayout();
    }
  },
)
```

## Règles par Type de Composant

### Navigation
- **Mobile (< 600px)** : Bottom navigation bar (5 items max)
- **Tablet (600–900px)** : Navigation rail (icônes + labels)
- **Desktop (> 900px)** : Sidebar complète avec sections

### Grilles
- **Mobile** : 1 colonne (ListView)
- **Tablet** : 2 colonnes (GridView)
- **Desktop** : 3–4 colonnes (GridView)

### Modals
- **Mobile** : Bottom sheet plein écran
- **Tablet+** : Dialog centré avec max-width 480px

### Tableaux
- **Mobile** : Cards empilées (pas de DataTable)
- **Tablet+** : DataTable avec scroll horizontal

## Tailles de Cible Tactile

- Boutons : minimum 48x48px
- Icônes cliquables : minimum 44x44px
- Espacement entre éléments cliquables : minimum 8px

## Orientation

- **Portrait** : layout vertical, scroll vertical
- **Paysage** : layout horizontal possible, utiliser l'espace supplémentaire
- **Auto-rotate** : activé sauf pendant les animations de jeu (dés)

## Images et Assets

- `CachedNetworkImage` avec placeholder `ShimmerLoader`
- `fit: BoxFit.cover` pour les images de profil
- `fit: BoxFit.contain` pour les logos et icônes de jeu

## Typographie Responsive

```dart
// Taille de texte adaptative
final fontSize = clamp(
  constraints.maxWidth * 0.04, // 4% de la largeur
  14.0,  // minimum
  24.0,  // maximum
);
```

## Tests Responsive

1. Tester chaque écran à 360px, 600px, 900px, 1200px
2. Vérifier l'overflow avec `debugOverflowMode`
3. Valider les zones tactiles minimales (48x48px)
4. Tester en orientation portrait ET paysage
