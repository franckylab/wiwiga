# Responsivité Progressive WIWIGA

## Portée
Cette règle s'applique à TOUS les écrans, widgets et composants Flutter de WIWIGA.

**OBLIGATION** : Chaque interface DOIT s'adapter automatiquement à TOUTE taille d'écran de **50px à 2300px** avec au moins **15 niveaux de responsivité**.

---

## 1. Système de 15+ Breakpoints

### Grille de Responsivité WIWIGA

| Niveau | Breakpoint | Catégorie | Devices Cibles | Facteur Échelle |
|--------|-----------|-----------|----------------|-----------------|
| 1 | 50px - 100px | Micro | Montres connectées | 0.25x |
| 2 | 101px - 180px | Nano | Mini écrans IoT | 0.35x |
| 3 | 181px - 240px | Ultra Petit | Téléphones anciens | 0.45x |
| 4 | 241px - 320px | Très Petit | Smartphones compacts | 0.55x |
| 5 | 321px - 360px | Petit | Android standard | 0.65x |
| 6 | 361px - 400px | Moyen-Petit | Android moyen | 0.75x |
| 7 | 401px - 480px | Moyen | Android large | 0.85x |
| 8 | 481px - 600px | Grand Mobile | Phablettes | 0.95x |
| 9 | 601px - 768px | Petite Tablette | iPad Mini, Tablettes 7" | 1.0x (base) |
| 10 | 769px - 900px | Tablette | iPad, Tablettes 10" | 1.1x |
| 11 | 901px - 1024px | Grande Tablette | iPad Pro, Tablets 12" | 1.2x |
| 12 | 1025px - 1280px | Laptop Petit | Netbooks, 13" | 1.35x |
| 13 | 1281px - 1440px | Laptop Standard | 14"-15" HD | 1.5x |
| 14 | 1441px - 1600px | Desktop Petit | Écrans 17"-19" | 1.65x |
| 15 | 1601px - 1920px | Desktop Full HD | Écrans 21"-24" | 1.8x |
| 16 | 1921px - 2300px | Desktop Large | Écrans 27"+, 2K | 2.0x |
| 17 | 2301px+ | Ultra Large | 4K, Écrans gaming | 2.2x+ |

---

## 2. Implementation Flutter

### 2.1 Classe ResponsiveConfig

```dart
/// ==================================
/// WIWIGA - Configuration Responsive
/// ==================================
/// Auteur: Franck Arlos CHENDJOU
/// Description: Système de 15+ breakpoints pour adaptation proportionnelle

import 'package:flutter/material.dart';

/// Catégorie d'écran
enum ScreenCategory {
  micro,         // 50-100px
  nano,          // 101-180px
  ultraSmall,    // 181-240px
  verySmall,     // 241-320px
  small,         // 321-360px
  mediumSmall,   // 361-400px
  medium,        // 401-480px
  largeMobile,   // 481-600px
  smallTablet,   // 601-768px
  tablet,        // 769-900px
  largeTablet,   // 901-1024px
  smallLaptop,   // 1025-1280px
  laptop,        // 1281-1440px
  smallDesktop,  // 1441-1600px
  desktop,       // 1601-1920px
  largeDesktop,  // 1921-2300px
  ultraWide,     // 2301px+
}

/// Configuration responsive complète
class ResponsiveConfig {
  final double screenWidth;
  final double screenHeight;
  final ScreenCategory category;
  final double scaleFactor;
  
  // Facteurs proportionnels
  final double iconSize;
  final double fontSize;
  final double spacing;
  final double padding;
  final double borderRadius;
  final double buttonHeight;
  final double inputHeight;
  final double cardPadding;
  
  const ResponsiveConfig({
    required this.screenWidth,
    required this.screenHeight,
    required this.category,
    required this.scaleFactor,
    required this.iconSize,
    required this.fontSize,
    required this.spacing,
    required this.padding,
    required this.borderRadius,
    required this.buttonHeight,
    required this.inputHeight,
    required this.cardPadding,
  });
  
  /// Calcule la configuration depuis la taille d'écran
  factory ResponsiveConfig.fromSize({
    required double width,
    required double height,
  }) {
    final category = _getScreenCategory(width);
    final baseScale = _getScaleFactor(width);
    
    // Calcul proportionnel de tous les éléments
    return ResponsiveConfig(
      screenWidth: width,
      screenHeight: height,
      category: category,
      scaleFactor: baseScale,
      
      // Éléments UI proportionnels
      iconSize: _scaleValue(baseScale, 24),      // Base: 24px
      fontSize: _scaleValue(baseScale, 16),       // Base: 16px
      spacing: _scaleValue(baseScale, 8),         // Base: 8px
      padding: _scaleValue(baseScale, 16),        // Base: 16px
      borderRadius: _scaleValue(baseScale, 12),   // Base: 12px
      buttonHeight: _scaleValue(baseScale, 48),   // Base: 48px
      inputHeight: _scaleValue(baseScale, 56),    // Base: 56px
      cardPadding: _scaleValue(baseScale, 16),    // Base: 16px
    );
  }
  
  /// Détermine la catégorie d'écran
  static ScreenCategory _getScreenCategory(double width) {
    if (width <= 100) return ScreenCategory.micro;
    if (width <= 180) return ScreenCategory.nano;
    if (width <= 240) return ScreenCategory.ultraSmall;
    if (width <= 320) return ScreenCategory.verySmall;
    if (width <= 360) return ScreenCategory.small;
    if (width <= 400) return ScreenCategory.mediumSmall;
    if (width <= 480) return ScreenCategory.medium;
    if (width <= 600) return ScreenCategory.largeMobile;
    if (width <= 768) return ScreenCategory.smallTablet;
    if (width <= 900) return ScreenCategory.tablet;
    if (width <= 1024) return ScreenCategory.largeTablet;
    if (width <= 1280) return ScreenCategory.smallLaptop;
    if (width <= 1440) return ScreenCategory.laptop;
    if (width <= 1600) return ScreenCategory.smallDesktop;
    if (width <= 1920) return ScreenCategory.desktop;
    if (width <= 2300) return ScreenCategory.largeDesktop;
    return ScreenCategory.ultraWide;
  }
  
  /// Calcule le facteur d'échelle (base 1.0 = 768px)
  static double _getScaleFactor(double width) {
    if (width <= 100) return 0.25;
    if (width <= 180) return 0.35;
    if (width <= 240) return 0.45;
    if (width <= 320) return 0.55;
    if (width <= 360) return 0.65;
    if (width <= 400) return 0.75;
    if (width <= 480) return 0.85;
    if (width <= 600) return 0.95;
    if (width <= 768) return 1.0;   // Base
    if (width <= 900) return 1.1;
    if (width <= 1024) return 1.2;
    if (width <= 1280) return 1.35;
    if (width <= 1440) return 1.5;
    if (width <= 1600) return 1.65;
    if (width <= 1920) return 1.8;
    if (width <= 2300) return 2.0;
    return 2.2 + ((width - 2300) / 1000); // Progressif au-delà
  }
  
  /// Applique l'échelle à une valeur de base
  static double _scaleValue(double scale, double baseValue) {
    return (baseValue * scale).clamp(4, 200); // Min 4px, Max 200px
  }
  
  /// Méthodes utilitaires pour calculer des valeurs responsives
  double scale(double baseValue) => _scaleValue(scaleFactor, baseValue);
  double scaleIcon(double baseSize) => _scaleValue(scaleFactor, baseSize);
  double scaleFont(double baseSize) => _scaleValue(scaleFactor, baseSize);
  double scaleSpacing(double baseValue) => _scaleValue(scaleFactor, baseValue);
  
  /// Vérifie si l'écran est dans une catégorie
  bool isMobile => screenWidth < 600;
  bool isTablet => screenWidth >= 600 && screenWidth < 1024;
  bool isDesktop => screenWidth >= 1024;
  bool isSmallScreen => screenWidth < 360;
  bool isLargeScreen => screenWidth >= 1600;
}
```

### 2.2 Widget ResponsiveBuilder

```dart
/// Builder responsive pour adapter le layout
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveConfig config, BoxConstraints constraints) builder;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final config = ResponsiveConfig.fromSize(
          width: constraints.maxWidth,
          height: MediaQuery.of(context).size.height,
        );
        
        return builder(context, config, constraints);
      },
    );
  }
}

/// Widget adaptatif pour grilles
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minChildWidth;
  final double spacing;
  final double runSpacing;
  
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minChildWidth = 200,
    this.spacing = 16,
    this.runSpacing = 16,
  });
  
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, config, constraints) {
        return Wrap(
          spacing: config.scaleSpacing(spacing),
          runSpacing: config.scaleSpacing(runSpacing),
          children: children.map((child) {
            return SizedBox(
              width: _calculateChildWidth(config, constraints),
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
  
  double _calculateChildWidth(ResponsiveConfig config, BoxConstraints constraints) {
    final width = config.screenWidth;
    
    if (width < 480) return width;                    // Mobile: 1 colonne
    if (width < 768) return (width - config.spacing * 3) / 2; // Tablette: 2 colonnes
    if (width < 1024) return (width - config.spacing * 4) / 3; // Petite tablette: 3 colonnes
    if (width < 1440) return (width - config.spacing * 5) / 4; // Laptop: 4 colonnes
    return (width - config.spacing * 6) / 5;          // Desktop: 5 colonnes
  }
}
```

### 2.3 Extension TextStyle Responsive

```dart
/// Extensions pour typographie responsive
extension ResponsiveTextStyle on BuildContext {
  ResponsiveConfig get responsive => ResponsiveConfig.fromSize(
    width: MediaQuery.of(this).size.width,
    height: MediaQuery.of(this).size.height,
  );
  
  /// Texte responsive
  TextStyle responsiveTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    final config = ResponsiveConfig.fromSize(
      width: MediaQuery.of(this).size.width,
      height: MediaQuery.of(this).size.height,
    );
    
    return TextStyle(
      fontSize: config.scaleFont(fontSize ?? 16),
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}
```

---

## 3. Guidelines d'Adaptation par Élément

### 3.1 Icônes

| Breakpoint | Taille Icône | Exemple Utilisation |
|-----------|-------------|---------------------|
| 50-180px | 12-16px | Micro interfaces |
| 181-320px | 16-20px | Téléphones compacts |
| 321-480px | 20-24px | Android standard |
| 481-768px | 24-28px | Phablettes, tablettes |
| 769-1024px | 28-32px | Tablettes larges |
| 1025-1440px | 32-40px | Laptops |
| 1441-1920px | 40-48px | Desktop |
| 1921px+ | 48-64px | Écrans larges |

```dart
// ✅ CORRECT — Icône responsive
Icon(
  Icons.account_balance_wallet,
  size: config.scaleIcon(24),  // S'adapte automatiquement
)

// ❌ INCORRECT — Taille fixe
Icon(
  Icons.account_balance_wallet,
  size: 24,  // Ne s'adapte pas
)
```

### 3.2 Typographie

| Breakpoint | Taille Texte Base | Titre H1 | Sous-titre |
|-----------|------------------|----------|------------|
| 50-180px | 8-10px | 16px | 12px |
| 181-320px | 10-12px | 20px | 14px |
| 321-480px | 12-14px | 24px | 16px |
| 481-768px | 14-16px | 28px | 18px |
| 769-1024px | 16-18px | 32px | 20px |
| 1025-1440px | 18-20px | 36px | 22px |
| 1441-1920px | 20-24px | 42px | 26px |
| 1921px+ | 24-28px | 48px+ | 30px+ |

**WIWIGA Spécial - Montants Financiers** :
- Mobile (<480px) : **Minimum 20px** pour lisibilité montants
- Tablette (768px) : **28px** pour montants
- Desktop (1440px) : **36px** pour montants
- Large (1920px+) : **44px** pour montants

```dart
// ✅ CORRECT — Montant financier responsive
Text(
  '${wallet.balance} FCFA',
  style: TextStyle(
    fontSize: config.scaleFont(config.isMobile ? 20 : 36),
    fontWeight: FontWeight.bold,
  ),
)
```

### 3.3 Espacements et Padding

| Breakpoint | Padding Card | Espacement | Margin |
|-----------|-------------|-----------|--------|
| 50-180px | 4-6px | 2-4px | 4px |
| 181-320px | 6-8px | 4-6px | 6px |
| 321-480px | 8-12px | 6-8px | 8px |
| 481-768px | 12-16px | 8-12px | 12px |
| 769-1024px | 16-20px | 12-16px | 16px |
| 1025-1440px | 20-24px | 16-20px | 20px |
| 1441-1920px | 24-32px | 20-24px | 24px |
| 1921px+ | 32-40px | 24-32px | 32px |

```dart
// ✅ CORRECT — Padding responsive
Container(
  padding: EdgeInsets.all(config.padding),
  child: Column(
    children: [
      SizedBox(height: config.spacing),
      // ...
    ],
  ),
)
```

### 3.4 Boutons

| Breakpoint | Hauteur | Padding Horizontal | Taille Texte |
|-----------|---------|-------------------|--------------|
| 50-180px | 24-32px | 8-12px | 10-12px |
| 181-320px | 32-40px | 12-16px | 12-14px |
| 321-480px | 40-48px | 16-20px | 14-16px |
| 481-768px | 48-52px | 20-24px | 16px |
| 769-1024px | 52-56px | 24-28px | 16-18px |
| 1025-1440px | 56-60px | 28-32px | 18px |
| 1441-1920px | 60-64px | 32-36px | 20px |
| 1921px+ | 64-72px | 36-40px | 22px |

```dart
// ✅ CORRECT — Bouton responsive
SizedBox(
  height: config.buttonHeight,
  child: ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: config.scaleSpacing(24),
      ),
    ),
    child: Text(
      'Placer un pari',
      style: TextStyle(
        fontSize: config.scaleFont(16),
      ),
    ),
  ),
)
```

### 3.5 Champs de Formulaire

| Breakpoint | Hauteur | Padding | Taille Texte |
|-----------|---------|---------|--------------|
| 50-180px | 32-40px | 8px | 10-12px |
| 181-320px | 40-48px | 10px | 12-14px |
| 321-480px | 48-56px | 12px | 14-16px |
| 481-768px | 56-60px | 14px | 16px |
| 769-1024px | 60-64px | 16px | 16-18px |
| 1025px+ | 64-72px | 16-20px | 18px |

### 3.6 Cartes et Conteneurs

| Breakpoint | Border Radius | Épaisseur Bordure | Shadow Blur |
|-----------|--------------|-------------------|-------------|
| 50-180px | 4-6px | 0.5px | 2px |
| 181-320px | 6-8px | 1px | 4px |
| 321-480px | 8-10px | 1px | 6px |
| 481-768px | 10-12px | 1px | 8px |
| 769-1024px | 12-16px | 1.5px | 10px |
| 1025-1440px | 16-20px | 1.5px | 12px |
| 1441-1920px | 20-24px | 2px | 16px |
| 1921px+ | 24-32px | 2px | 20px |

---

## 4. Pattern d'Écran Responsive Obligatoire

### 4.1 Template Écran WIWIGA

```dart
/// ==================================
/// WIWIGA - Template Écran Responsive
/// ==================================
/// Auteur: Franck Arlos CHENDJOU
/// Description: Pattern obligatoire pour TOUS les écrans

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: ResponsiveBuilder(
          builder: (context, config, constraints) {
            return Text(
              'Portefeuille',
              style: TextStyle(
                fontSize: config.scaleFont(20),
              ),
            );
          },
        ),
      ),
      body: ResponsiveBuilder(
        builder: (context, config, constraints) {
          // Layout adaptatif selon la taille
          if (config.isMobile) {
            return _buildMobileLayout(context, wallet, config);
          } else if (config.isTablet) {
            return _buildTabletLayout(context, wallet, config);
          } else {
            return _buildDesktopLayout(context, wallet, config);
          }
        },
      ),
    );
  }
  
  /// Layout Mobile (<600px)
  Widget _buildMobileLayout(BuildContext context, WalletState wallet, ResponsiveConfig config) {
    return ListView(
      padding: EdgeInsets.all(config.padding),
      children: [
        // Card solde pleine largeur
        _BalanceCard(wallet: wallet, config: config),
        SizedBox(height: config.spacing * 2),
        
        // Boutons empilés verticalement
        _ActionButtonsVertical(wallet: wallet, config: config),
        SizedBox(height: config.spacing * 2),
        
        // Liste transactions
        _TransactionList(wallet: wallet, config: config),
      ],
    );
  }
  
  /// Layout Tablette (600-1024px)
  Widget _buildTabletLayout(BuildContext context, WalletState wallet, ResponsiveConfig config) {
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.all(config.padding),
      mainAxisSpacing: config.spacing * 2,
      crossAxisSpacing: config.spacing * 2,
      children: [
        _BalanceCard(wallet: wallet, config: config),
        _QuickActionsCard(wallet: wallet, config: config),
        _TransactionListFullWidth(wallet: wallet, config: config),
      ],
    );
  }
  
  /// Layout Desktop (>1024px)
  Widget _buildDesktopLayout(BuildContext context, WalletState wallet, ResponsiveConfig config) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Colonne gauche: Solde + Actions (60%)
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _BalanceCard(wallet: wallet, config: config),
              SizedBox(height: config.spacing * 2),
              _QuickActionsCard(wallet: wallet, config: config),
            ],
          ),
        ),
        SizedBox(width: config.spacing * 3),
        
        // Colonne droite: Historique (40%)
        Expanded(
          flex: 2,
          child: _TransactionList(wallet: wallet, config: config),
        ),
      ],
    );
  }
}
```

### 4.2 Carte Responsive

```dart
class _BalanceCard extends StatelessWidget {
  final WalletState wallet;
  final ResponsiveConfig config;
  
  const _BalanceCard({required this.wallet, required this.config});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: config.scale(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(config.borderRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(config.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solde disponible',
              style: TextStyle(
                fontSize: config.scaleFont(14),
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: config.spacing),
            Text(
              '${wallet.balance.toString().replaceAllMapped(
                RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                (match) => '${match[1]} ',
              )} FCFA',
              style: TextStyle(
                fontSize: config.scaleFont(config.isMobile ? 20 : 36),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 5. Cas Spéciaux WIWIGA

### 5.1 Écran de Jeu de Dés

```dart
class DiceGameScreen extends ConsumerStatefulWidget {
  const DiceGameScreen({super.key});
  
  @override
  ConsumerState<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends ConsumerState<DiceGameScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveBuilder(
        builder: (context, config, constraints) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Zone dés adaptative
              _DiceZone(config: config),
              SizedBox(height: config.spacing * 3),
              
              // Contrôles de mise
              _BettingControls(config: config),
              SizedBox(height: config.spacing * 2),
              
              // Bouton lancer
              SizedBox(
                width: config.isMobile ? double.infinity : config.scale(200),
                height: config.buttonHeight,
                child: ElevatedButton(
                  onPressed: _rollDice,
                  child: Text(
                    'Lancer les dés',
                    style: TextStyle(
                      fontSize: config.scaleFont(18),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiceZone extends StatelessWidget {
  final ResponsiveConfig config;
  
  const _DiceZone({required this.config});
  
  @override
  Widget build(BuildContext context) {
    // Taille dés proportionnelle à l'écran
    final diceSize = config.scale(config.isMobile ? 80 : 120);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.casino, size: diceSize),
        SizedBox(width: config.spacing),
        Icon(Icons.casino, size: diceSize),
      ],
    );
  }
}
```

### 5.2 Dialog Responsive

```dart
void showResponsiveDialog(BuildContext context, Widget content) {
  final config = ResponsiveConfig.fromSize(
    width: MediaQuery.of(context).size.width,
    height: MediaQuery.of(context).size.height,
  );
  
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: config.isMobile ? config.padding : config.scale(100),
          vertical: config.scaleSpacing(40),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: config.scale(config.isMobile ? 350 : 600),
          ),
          child: content,
        ),
      );
    },
  );
}
```

---

## 6. Checklist Responsivité

### Pré-Commit Obligatoire

- [ ] **TOUS** les écrans utilisent `ResponsiveBuilder`
- [ ] **AUCUNE** taille fixe (px) sans scaling
- [ ] Icônes responsives avec `config.scaleIcon()`
- [ ] Textes responsives avec `config.scaleFont()`
- [ ] Espacements responsifs avec `config.spacing`
- [ ] Padding responsif avec `config.padding`
- [ ] Boutons avec `config.buttonHeight`
- [ ] Layout adaptatif mobile/tablette/desktop
- [ ] Montants financiers **minimum 20px** sur mobile
- [ ] Testé sur 3 breakpoints minimum (360px, 768px, 1440px)
- [ ] Dialogs et modals responsifs
- [ ] Grilles avec nombre de colonnes adaptatif

### Tests Responsivité

- [ ] Test Android 360x640 (niveau 5)
- [ ] Test Android 412x915 (niveau 7)
- [ ] Test Tablette 768x1024 (niveau 9)
- [ ] Test Laptop 1366x768 (niveau 12)
- [ ] Test Desktop 1920x1080 (niveau 15)

---

## 7. Anti-patterns Responsivité

### INTERDITS ABSOLUS

- ❌ `fontSize: 16` (taille fixe)
- ❌ `Icon(size: 24)` (non responsive)
- ❌ `padding: EdgeInsets.all(16)` (padding fixe)
- ❌ `width: 200` (largeur fixe sans condition)
- ❌ `SizedBox(height: 24)` (espacement fixe)
- ❌ Layout unique pour mobile et desktop
- ❌ Hardcoded dimensions dans les widgets
- ❌ Ignorer les petits écrans (<320px)

### OBLIGATOIRE

- ✅ TOUJOURS utiliser `config.scale()` pour dimensions
- ✅ TOUJOURS tester sur mobile (<480px)
- ✅ TOUJOURS layout adaptatif selon catégorie
- ✅ TOUJOURS montants financiers lisibles (min 20px mobile)
- ✅ TOUJOURS espacements proportionnels

---

## 8. Utilitaires Avancés

### 8.1 Hook Responsive

```dart
/// Hook pour récupérer config responsive dans ConsumerWidget
extension ResponsiveHook on WidgetRef {
  ResponsiveConfig get responsive {
    // Utiliser MediaQuery via context disponible
    throw UnimplementedError('Utiliser ResponsiveBuilder à la place');
  }
}
```

### 8.2 MediaQuery Helper

```dart
/// Extension pour accès rapide
extension ResponsiveContext on BuildContext {
  ResponsiveConfig get responsiveConfig => ResponsiveConfig.fromSize(
    width: MediaQuery.of(this).size.width,
    height: MediaQuery.of(this).size.height,
  );
  
  bool get isMobile => responsiveConfig.isMobile;
  bool get isTablet => responsiveConfig.isTablet;
  bool get isDesktop => responsiveConfig.isDesktop;
}
```

### 8.3 Widget Pré-construits

```dart
/// Spacer responsive
class ResponsiveSpacer extends StatelessWidget {
  final double factor; // 1 = spacing base, 2 = 2x spacing
  
  const ResponsiveSpacer({super.key, this.factor = 1});
  
  @override
  Widget build(BuildContext context) {
    final config = context.responsiveConfig;
    return SizedBox(height: config.spacing * factor);
  }
}

/// Divider responsive
class ResponsiveDivider extends StatelessWidget {
  const ResponsiveDivider({super.key});
  
  @override
  Widget build(BuildContext context) {
    final config = context.responsiveConfig;
    return Divider(
      thickness: config.scale(1),
      height: config.spacing * 2,
    );
  }
}
```

---

## 9. Performance

### Optimisation Calcul Responsif

```dart
/// Cache la configuration pour éviter recalculs
class ResponsiveCache {
  static final Map<String, ResponsiveConfig> _cache = {};
  
  static ResponsiveConfig getConfig(double width, double height) {
    final key = '${width.toInt()}x${height.toInt()}';
    return _cache.putIfAbsent(key, () {
      return ResponsiveConfig.fromSize(width: width, height: height);
    });
  }
  
  static void clear() => _cache.clear();
}
```

---

**Cette règle est OBLIGATOIRE pour TOUT développement WIWIGA. Tout écran non responsive sera rejeté en code review.**

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 23 Juin 2026  
**Version**: 1.0  
**Breakpoints**: 17 niveaux (50px - 2300px+)
