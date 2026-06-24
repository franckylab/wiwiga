# Skill: Composants Néon WIWIGA

## Description
Implémenter les 10 composants obligatoires du design system néon gaming WIWIGA avec effets glow, animations riches, et configuration dynamique.

## Quand Utiliser
- Créer un nouveau bouton, carte, input ou modal
- Implémenter des effets visuels néon (glow, pulse, shimmer)
- Afficher des montants financiers ou des cartes de jeux
- Gérer la navigation responsive (mobile → desktop)
- Afficher des animations de victoire/gain

## Règles Absolues
- ✅ **TOUJOURS** utiliser ces composants, JAMAIS les widgets Material natifs directement
- ✅ **TOUJOURS** respecter les durées d'animation (100/200/300ms)
- ✅ **TOUJOURS** utiliser les couleurs de `NeonColors`
- ✅ **TOUJOURS** rendre les composants responsives avec `ResponsiveConfig`
- ❌ **JAMAIS** hardcoder des couleurs ou des tailles
- ❌ **JAMAIS** utiliser `ElevatedButton`, `Card`, `TextFormField` natifs

---

## 1. NeonButton

### Usage
Remplace `ElevatedButton`. Bouton avec effet glow et variantes.

### Paramètres
```dart
NeonButton({
  required String text,
  required VoidCallback onPressed,
  NeonButtonType type = NeonButtonType.primary,  // primary, secondary, danger, success
  IconData? icon,              // Icône Font Awesome optionnelle
  bool isLoading = false,      // Affiche shimmer loader
  bool isFullWidth = false,    // Largeur 100%
  double? width,               // Largeur custom
})
```

### Exemple d'Utilisation
```dart
// Bouton principal
NeonButton(
  text: 'Jouer maintenant',
  onPressed: () => _startGame(),
  type: NeonButtonType.primary,
  icon: FontAwesomeIcons.dice,
)

// Bouton danger
NeonButton(
  text: 'Supprimer',
  onPressed: () => _delete(),
  type: NeonButtonType.danger,
)

// Bouton loading
NeonButton(
  text: 'Déposer',
  onPressed: () {},
  isLoading: _isProcessing,
  type: NeonButtonType.success,
)
```

### Implémentation Clé
```dart
class NeonButton extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: NeonAnimations.standard,
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(NeonRadius.small),
        boxShadow: _isHovered 
          ? NeonShadows.glow(NeonColors.primary, opacity: NeonGlow.opacityMedium)
          : NeonShadows.small(NeonColors.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(NeonRadius.small),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: config.scaleSpacing(24),
              vertical: config.scaleSpacing(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) Icon(widget.icon, size: config.iconSize),
                if (widget.icon != null) SizedBox(width: config.spacingSmall),
                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: config.scaleFont(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

### Tests Requis
- [ ] Rendu selon type (primary, secondary, danger, success)
- [ ] Glow effect au hover
- [ ] État loading avec shimmer
- [ ] Responsive sur 3 breakpoints

---

## 2. NeonCard

### Usage
Remplace `Card`. Carte avec bordure lumineuse au hover et effet scale.

### Paramètres
```dart
NeonCard({
  required Widget child,
  VoidCallback? onTap,         // Clickable si défini
  Color? glowColor,            // Couleur du glow (défaut: primary)
  double? width,               // Largeur custom
  EdgeInsets? padding,         // Padding interne
})
```

### Exemple
```dart
NeonCard(
  onTap: () => _navigateToGame(),
  child: Column(
    children: [
      Image.asset('assets/dice-game.png'),
      Text('Jeu de Dés'),
      Text('Mise: 100 - 50 000 FCFA'),
    ],
  ),
)
```

### Implémentation Clé
```dart
class NeonCard extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: NeonAnimations.standard,
      transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
      decoration: BoxDecoration(
        color: NeonColors.card,
        borderRadius: BorderRadius.circular(NeonRadius.medium),
        border: Border.all(
          color: _isHovered 
            ? (widget.glowColor ?? NeonColors.primary).withOpacity(NeonGlow.opacityMedium)
            : Colors.transparent,
          width: _isHovered ? NeonGlow.borderWidthMedium : 0,
        ),
        boxShadow: _isHovered
          ? NeonShadows.large(NeonColors.primary)
          : NeonShadows.small(NeonColors.background),
      ),
      child: child,
    );
  }
}
```

---

## 3. NeonInput

### Usage
Remplace `TextFormField`. Input avec border glow au focus.

### Paramètres
```dart
NeonInput({
  required String label,
  required TextEditingController controller,
  String? hint,
  IconData? prefixIcon,
  IconData? suffixIcon,
  bool obscureText = false,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
  int maxLines = 1,
})
```

### Exemple
```dart
NeonInput(
  label: 'Montant du dépôt',
  controller: _amountController,
  hint: 'Ex: 5000',
  prefixIcon: FontAwesomeIcons.moneyBill,
  keyboardType: TextInputType.number,
  validator: (value) {
    if (value == null || value.isEmpty) return 'Montant requis';
    if (int.parse(value) < 500) return 'Minimum 500 FCFA';
    return null;
  },
)
```

---

## 4. GlowBadge

### Usage
Badge avec animation de pulse continue pour notifications et statuts.

### Paramètres
```dart
GlowBadge({
  required String text,
  GlowBadgeType type = GlowBadgeType.notification,  // notification, status, rank
  Color? color,                  // Couleur custom
  bool pulse = true,             // Animation pulse
})
```

### Exemple
```dart
// Notification
GlowBadge(
  text: '3',
  type: GlowBadgeType.notification,
  color: NeonColors.error,
)

// Rang
GlowBadge(
  text: 'Or',
  type: GlowBadgeType.rank,
  color: NeonColors.rankGold,
)

// Statut jeu
GlowBadge(
  text: 'En cours',
  type: GlowBadgeType.status,
  color: NeonColors.gameInProgress,
)
```

---

## 5. BalanceDisplay

### Usage
Affichage du solde FCFA avec formatage et animation de mise à jour.

### Paramètres
```dart
BalanceDisplay({
  required double balance,
  bool showLabel = true,
  TextStyle? amountStyle,
  VoidCallback? onTap,         // Clickable pour détails
})
```

### Exemple
```dart
BalanceDisplay(
  balance: 125000.0,
  showLabel: true,
)
// Affiche: "Solde: 125 000 FCFA" avec Orbitron et glow
```

### Implémentation Clé
```dart
class BalanceDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(config.cardPadding),
      decoration: BoxDecoration(
        gradient: NeonGradients.balance,
        borderRadius: BorderRadius.circular(NeonRadius.medium),
        boxShadow: NeonShadows.glow(NeonColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLabel)
            Text(
              'Solde disponible',
              style: TextStyle(
                fontSize: config.scaleFont(14),
                color: Colors.white70,
              ),
            ),
          SizedBox(height: config.spacingSmall),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: _previousBalance, end: widget.balance),
            duration: NeonAnimations.transition,
            builder: (context, value, child) {
              return Text(
                '${_formatFCFA(value)} FCFA',
                style: AppTypography.balanceAmount(
                  fontSize: config.isMobile ? 20 : 36,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  String _formatFCFA(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]} ',
    );
  }
}
```

---

## 6. GameCard

### Usage
Carte de jeu complète avec image, infos et bouton "Jouer".

### Paramètres
```dart
GameCard({
  required GameModel game,
  required VoidCallback onPlay,
})
```

### Exemple
```dart
GameCard(
  game: diceGame,
  onPlay: () => _joinGame(diceGame),
)
```

---

## 7. NeonModal

### Usage
Modal avec backdrop blur et bordure lumineuse.

### Paramètres
```dart
NeonModal.show({
  required BuildContext context,
  required String title,
  required Widget content,
  List<Widget>? actions,
  bool dismissible = true,
})
```

### Exemple
```dart
NeonModal.show(
  context: context,
  title: 'Confirmer le dépôt',
  content: Text('Voulez-vous déposer 5 000 FCFA ?'),
  actions: [
    NeonButton(
      text: 'Annuler',
      onPressed: () => Navigator.pop(context),
      type: NeonButtonType.secondary,
    ),
    NeonButton(
      text: 'Confirmer',
      onPressed: () => _confirmDeposit(),
      type: NeonButtonType.primary,
    ),
  ],
)
```

---

## 8. ShimmerLoader

### Usage
Animation de chargement shimmer au lieu de CircularProgressIndicator.

### Paramètres
```dart
ShimmerLoader({
  double? width,
  double? height,
  BorderRadius? borderRadius,
})
```

### Exemple
```dart
// Liste en chargement
ListView.builder(
  itemCount: 5,
  itemBuilder: (context, index) {
    return Padding(
      padding: EdgeInsets.all(config.spacing),
      child: ShimmerLoader(
        height: 100,
        borderRadius: BorderRadius.circular(NeonRadius.medium),
      ),
    );
  },
)
```

---

## 9. VictoryEffect

### Usage
Animation de victoire avec particules et montant du gain.

### Paramètres
```dart
VictoryEffect.show({
  required BuildContext context,
  required double amount,
  Duration duration = const Duration(seconds: 3),
})
```

### Exemple
```dart
// Après victoire
VictoryEffect.show(
  context: context,
  amount: 50000.0,
  duration: Duration(seconds: 3),
)
// Affiche particules + "Vous avez gagné 50 000 FCFA !"
```

---

## 10. ResponsiveNavigation

### Usage
Navigation adaptative selon la taille d'écran.

### Comportement
- **Mobile (<600px)** : BottomNavigationBar (Jeux, Wallet, Profil)
- **Tablette (600-1024px)** : NavigationRail compacte
- **Desktop (>1024px)** : Sidebar complète avec logo + "Mes jeux récents"

### Exemple
```dart
Scaffold(
  body: _buildBody(),
  bottomNavigationBar: config.isMobile 
    ? ResponsiveNavigation(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          NavigationDestination(icon: Icon(Icons.casino), label: 'Jeux'),
          NavigationDestination(icon: Icon(Icons.wallet), label: 'Portefeuille'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
        ],
      )
    : null,
)
```

---

## Bonnes Pratiques

### 1. Performance
- Utiliser `const` constructors quand possible
- Éviter rebuilds inutiles avec `AnimatedBuilder`
- Cache les configurations responsives

### 2. Accessibilité
- Contraste minimum 4.5:1 pour le texte
- Touch targets 44x44px minimum
- Labels sémantiques pour screen readers

### 3. Tests
```dart
// Test unitaire NeonButton
testWidgets('NeonButton displays correct text', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: NeonButton(
        text: 'Test',
        onPressed: () {},
      ),
    ),
  );
  
  expect(find.text('Test'), findsOneWidget);
});

// Test glow effect
testWidgets('NeonButton shows glow on hover', (tester) async {
  // Simuler hover
  await tester.sendEventTo(find.byType(NeonButton), 'hover');
  await tester.pump();
  
  // Vérifier boxShadow
  final container = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
  expect(container.decoration.boxShadow.length, greaterThan(0));
});
```

---

## Anti-Patterns

- ❌ Hardcoder des couleurs (toujours `NeonColors`)
- ❌ Utiliser widgets Material natifs directement
- ❌ Oublier le responsive (toujours `config.scale*()`)
- ❌ Durées d'animation > 300ms (sauf victory effect)
- ❌ Glow avec opacité > 0.7 (trop intense)
- ❌ Ombres avec opacité > 0.15

---

## Références
- **Design system** : `.qoder/rules/rl_design-system.md`
- **Thème néon** : `lib/core/theme/neon_theme.dart`
- **Responsive** : `.qoder/rules/rl_responsive-design.md`
- **Typographie** : `lib/core/theme/typography.dart`

---

**Ce skill est OBLIGATOIRE pour TOUT composant UI WIWIGA.**

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 24 Juin 2026  
**Version**: 1.0
