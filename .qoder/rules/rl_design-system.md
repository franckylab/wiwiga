# Design System Frontend WIWIGA - Néon Gaming

## Portée
Cette règle s'applique à TOUS les écrans, widgets et composants Flutter de WIWIGA. Elle définit le design system néon gaming, les standards visuels, et le système de configuration dynamique.

---

## 1. Palette de Couleurs Néon Gaming

### 1.1 Couleurs Principales
```dart
// Fichier: lib/core/theme/neon_theme.dart
NeonColors.primary      = #2DD4BF  // Vert émeraude (actions principales)
NeonColors.secondary    = #F59E0B  // Orange/doré (CTA importants)
NeonColors.accent       = #00D9FF  // Cyan (effets spéciaux)
NeonColors.background   = #1E293B  // Gris-bleu profond (fond)
NeonColors.surface      = #0F172A  // Plus sombre (surfaces)
NeonColors.card         = #1E293B  // Cartes
```

### 1.2 Couleurs Financières
```dart
NeonColors.success = #10B981  // Succès, gains
NeonColors.warning = #F59E0B  // Attention, limites
NeonColors.error   = #EF4444  // Erreurs, pertes
NeonColors.info    = #3B82F6  // Informations
```

### 1.3 Couleurs des Rangs
```dart
NeonColors.rankBronze    = #CD7F32
NeonColors.rankSilver    = #C0C0C0
NeonColors.rankGold      = #FFD700
NeonColors.rankPlatinum  = #E5E4E2
NeonColors.rankDiamond   = #B9F2FF
```

### 1.4 Couleurs des Méthodes de Paiement
```dart
NeonColors.paymentMTN     = #FFCC00  // MTN Mobile Money
NeonColors.paymentOrange  = #FF6600  // Orange Money
NeonColors.paymentCampay  = #00A650  // Campay
```

### 1.5 Couleurs des Statuts de Jeu
```dart
NeonColors.gameInProgress = #2DD4BF  // En cours
NeonColors.gameCompleted  = #10B981  // Terminé
NeonColors.gameCancelled  = #EF4444  // Annulé
NeonColors.gamePending    = #F59E0B  // En attente
```

---

## 2. Style des Composants Néon

### 2.1 Effets Glow
```dart
NeonGlow.opacityLow     = 0.3   // Subtil
NeonGlow.opacityMedium  = 0.5   // Standard
NeonGlow.opacityHigh    = 0.7   // Intense

NeonGlow.blurSmall      = 4.0
NeonGlow.blurMedium     = 8.0
NeonGlow.blurLarge      = 16.0
NeonGlow.blurExtraLarge = 24.0

NeonGlow.borderWidthThin    = 1.0
NeonGlow.borderWidthMedium  = 1.5
NeonGlow.borderWidthThick   = 2.0
```

### 2.2 Ombres
```dart
NeonShadows.maxOpacity = 0.15  // Opacité maximale

// Utilisation
NeonShadows.small(color)   // Ombre légère
NeonShadows.medium(color)  // Ombre standard
NeonShadows.large(color)   // Ombre prononcée
NeonShadows.glow(color)    // Effet de lueur
```

### 2.3 Gradients (Restreints)
**GRADIENTS AUTORISÉS UNIQUEMENT SUR** :
- Boutons CTA principaux (NeonGradients.primary)
- Cartes de solde (NeonGradients.balance)
- États hover des cartes de jeu (NeonGradients.gameCard)

**INTERDIT** : Gradients sur cartes standards, backgrounds, inputs

### 2.4 Coins Arrondis
```dart
NeonRadius.small      = 8.0   // Boutons, inputs
NeonRadius.medium     = 12.0  // Cartes
NeonRadius.large      = 16.0  // Modals
NeonRadius.extraLarge = 24.0  // Éléments spéciaux
```

---

## 3. Typographie

### 3.1 Polices
- **Inter** : Texte courant (body, labels, descriptions)
- **Orbitron** : Titres, headlines, montants financiers (effet gaming)

### 3.2 Styles Spéciaux
```dart
// Montants financiers (Orbitron)
AppTypography.balanceAmount(fontSize: 36)      // Desktop
AppTypography.balanceAmountMobile()            // Mobile (min 20px)

// Labels de jeux (Inter)
AppTypography.gameLabel(fontSize: 14)
```

### 3.3 Hiérarchie Responsive
Les tailles de police doivent utiliser `config.scaleFont()` selon les 17 breakpoints définis dans `rl_responsive-design.md`.

---

## 4. Animations

### 4.1 Durées Standard
```dart
NeonAnimations.micro      = 100ms  // Micro-interactions
NeonAnimations.standard   = 200ms  // Hover, tap effects
NeonAnimations.transition = 300ms  // Transitions de page
```

### 4.2 Types d'Animations
- **Glow pulse** : CTA principaux (boutons Jouer, Déposer)
- **Card hover** : Scale 1.02 + glow border + ombre accentuée
- **Victory effects** : Particules + Lottie pour les gains
- **Shimmer** : Loading states au lieu de spinners
- **Page transitions** : Slide + fade (300ms)

### 4.3 Courbes d'Animation
```dart
NeonAnimations.easeInOut = Curves.easeInOut
NeonAnimations.easeOut   = Curves.easeOut
NeonAnimations.bounce    = Curves.elasticOut
```

---

## 5. Composants Néon Obligatoires

**TOUS les écrans DOIVENT utiliser ces composants, JAMAIS les widgets Material natifs directement** :

### 5.1 Liste des 10 Composants
1. **NeonButton** - Remplace ElevatedButton (variantes: primary, secondary, danger, success)
2. **NeonCard** - Remplace Card (bordure lumineuse hover, scale 1.02)
3. **NeonInput** - Remplace TextFormField (border glow focus)
4. **GlowBadge** - Notifications avec pulse animation
5. **BalanceDisplay** - Affichage solde FCFA avec animation
6. **GameCard** - Cartes de jeux avec hover complet
7. **NeonModal** - Modals avec backdrop blur + bordure lumineuse
8. **ShimmerLoader** - Loading states animés
9. **VictoryEffect** - Particules + animation gains
10. **ResponsiveNavigation** - Bottom nav (mobile) → Sidebar (desktop)

### 5.2 Emplacement des Fichiers
```
lib/presentation/widgets/neon/
  ├── neon_button.dart
  ├── neon_card.dart
  ├── neon_input.dart
  ├── glow_badge.dart
  ├── neon_modal.dart
  └── shimmer_loader.dart

lib/presentation/widgets/game/
  ├── balance_display.dart
  ├── game_card.dart
  └── victory_effect.dart

lib/presentation/widgets/navigation/
  └── responsive_navigation.dart
```

---

## 6. Système de Configuration Dynamique

### 6.1 Principe
**WIWIGA doit être entièrement paramétrable et configurable via le dashboard administrateur**. Tous les paramètres visuels et fonctionnels doivent être :
- Configurables par les admins/super-admins selon leurs permissions
- Persistés en base de données
- Chargeables dynamiquement au démarrage de l'app
- Applicables en temps réel (hot reload si possible)

### 6.2 Paramètres Configurables

#### A. Paramètres Visuels (Thème)
```dart
// Table DB: ui_theme_configs
{
  "primary_color": "#2DD4BF",           // Modifiable
  "secondary_color": "#F59E0B",         // Modifiable
  "accent_color": "#00D9FF",            // Modifiable
  "background_color": "#1E293B",        // Modifiable
  "border_radius": 12.0,                // Modifiable
  "glow_intensity": 0.5,                // Modifiable (0.0 - 1.0)
  "animation_duration": 200,            // Modifiable (ms)
  "font_family_body": "Inter",          // Modifiable
  "font_family_display": "Orbitron",    // Modifiable
  "logo_url": "/assets/logo-neon.svg",  // Modifiable
  "favicon_url": "/assets/favicon.ico"  // Modifiable
}
```

#### B. Paramètres Fonctionnels
```dart
// Table DB: app_feature_configs
{
  "maintenance_mode": false,                    // Activable par admin
  "registration_enabled": true,                 // Ouvrir/fermer inscriptions
  "min_deposit_amount": 500,                    // Montant minimum dépôt
  "max_deposit_amount": 1000000,                // Montant maximum dépôt
  "min_withdrawal_amount": 1000,                // Montant minimum retrait
  "max_withdrawal_amount": 5000000,             // Montant maximum retrait
  "kyc_required_threshold": 100000,             // Seuil KYC obligatoire
  "max_games_per_user": 10,                     // Limite parties simultanées
  "websocket_timeout": 30000,                   // Timeout WebSocket (ms)
  "session_timeout": 1800000,                   // Timeout session (30min)
  "reality_check_interval": 1800000,            // Rappel réalité (30min)
  "self_exclusion_options": [24, 168, 720],     // Heures auto-exclusion
  "support_email": "support@wiwiga.cm",         // Email support
  "support_phone": "+237 6XX XXX XXX",          // Téléphone support
  "terms_url": "https://wiwiga.cm/terms",       // CGU
  "privacy_url": "https://wiwiga.cm/privacy"    // Politique confidentialité
}
```

#### C. Paramètres par Jeu
```dart
// Table DB: game_configs
{
  "dice_game": {
    "enabled": true,                            // Activer/désactiver jeu
    "min_bet": 100,                             // Mise minimum
    "max_bet": 500000,                          // Mise maximum
    "max_players": 2,                           // Joueurs max
    "dice_count": 1,                            // Nombre de dés
    "dice_type": 6,                             // Type de dés (6 faces)
    "roll_timeout": 10000,                      // Timeout lancé (ms)
    "commission_rate": 0.05,                    // Commission (5%)
    "animation_enabled": true,                  // Activer animations
    "sound_enabled": true                       // Activer sons
  }
}
```

#### D. Paramètres de Paiement
```dart
// Table DB: payment_configs
{
  "campay": {
    "enabled": true,                            // Activer Campay
    "min_amount": 500,                          // Montant minimum
    "max_amount": 1000000,                      // Montant maximum
    "api_key": "encrypted",                     // Clé API (chiffrée)
    "webhook_url": "/api/webhooks/campay"       // URL webhook
  },
  "mtn_momo": {
    "enabled": true,
    "min_amount": 500,
    "max_amount": 1000000
  },
  "orange_money": {
    "enabled": true,
    "min_amount": 500,
    "max_amount": 1000000
  }
}
```

### 6.3 Implémentation Backend

#### Modèle Elixir
```elixir
# Table: ui_theme_configs
defmodule GameHub.UI.ThemeConfig do
  use Ecto.Schema
  
  schema "ui_theme_configs" do
    field :primary_color, :string, default: "#2DD4BF"
    field :secondary_color, :string, default: "#F59E0B"
    field :accent_color, :string, default: "#00D9FF"
    field :background_color, :string, default: "#1E293B"
    field :border_radius, :float, default: 12.0
    field :glow_intensity, :float, default: 0.5
    field :animation_duration, :integer, default: 200
    field :font_family_body, :string, default: "Inter"
    field :font_family_display, :string, default: "Orbitron"
    field :logo_url, :string
    field :favicon_url, :string
    field :updated_by, :integer  # Admin ID
    timestamps()
  end
end
```

#### Endpoint de Configuration
```elixir
# Controller: ThemeConfigController
defmodule GameHubWeb.API.Admin.ThemeConfigController do
  use GameHubWeb, :controller
  
  # GET /api/admin/theme-config
  def get_config(conn, _params) do
    config = Repo.get_by(ThemeConfig, id: 1) || %ThemeConfig{}
    json(conn, %{success: true, data: config})
  end
  
  # PUT /api/admin/theme-config
  def update_config(conn, %{"theme_config" => params}) do
    config = Repo.get_by(ThemeConfig, id: 1) || %ThemeConfig{}
    
    changeset = ThemeConfig.changeset(config, params)
    
    case Repo.insert_or_update(changeset) do
      {:ok, updated} ->
        # Broadcast changement temps réel
        GameHubWeb.Endpoint.broadcast!("theme:update", %{config: updated})
        
        # Log d'audit
        AuditLog.log_admin_action(
          conn.assigns.current_user.id,
          "update_theme_config",
          "theme_config",
          updated.id,
          changeset.changes,
          conn
        )
        
        json(conn, %{success: true, data: updated})
      
      {:error, changeset} ->
        json(conn, %{success: false, error: changeset.errors})
    end
  end
end
```

### 6.4 Implémentation Frontend

#### Provider de Configuration
```dart
// Provider: theme_config_provider.dart
final themeConfigProvider = StateNotifierProvider<ThemeConfigNotifier, ThemeConfigState>((ref) {
  return ThemeConfigNotifier();
});

class ThemeConfigNotifier extends StateNotifier<ThemeConfigState> {
  ThemeConfigNotifier() : super(ThemeConfigState.loading()) {
    loadConfig();
  }
  
  Future<void> loadConfig() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final config = await apiService.getThemeConfig();
      state = ThemeConfigState.loaded(config);
      
      // Appliquer thème dynamiquement
      _applyTheme(config);
    } catch (e) {
      state = ThemeConfigState.error(e.toString());
    }
  }
  
  void _applyTheme(ThemeConfig config) {
    // Mettre à jour les couleurs du thème en runtime
    // Utiliser CustomPainter pour glow effects
    // Redessiner l'application avec nouveau thème
  }
}
```

#### Écoute des Changements Temps Réel
```dart
// WebSocket listener
class ThemeConfigListener {
  static void listen(WidgetRef ref) {
    final webSocket = ref.watch(webSocketProvider);
    
    webSocket.subscribe('theme:update', (data) {
      // Recharger configuration
      ref.read(themeConfigProvider.notifier).loadConfig();
      
      // Notification utilisateur
      showSnackBar('Thème mis à jour avec succès');
    });
  }
}
```

### 6.5 Permissions Admin

| Paramètre | Super Admin | Admin | Modérateur |
|-----------|-------------|-------|------------|
| Couleurs thème | ✅ | ✅ | ❌ |
| Logo/Favicon | ✅ | ✅ | ❌ |
| Paramètres fonctionnels | ✅ | ✅ | ❌ |
| Configurations jeux | ✅ | ✅ | ❌ |
| Configurations paiement | ✅ | ❌ | ❌ |
| Maintenance mode | ✅ | ✅ | ❌ |

---

## 7. Checklist Pré-Commit Design System

### Composants
- [ ] **TOUS** les boutons utilisent `NeonButton` (pas `ElevatedButton` natif)
- [ ] **TOUTES** les cartes utilisent `NeonCard` avec effets hover
- [ ] **TOUS** les inputs utilisent `NeonInput` avec border glow
- [ ] Gradients **UNIQUEMENT** sur CTA principaux et cartes de solde
- [ ] Glow effects avec opacité 0.4-0.6
- [ ] Ombres max `Colors.black.withOpacity(0.15)`
- [ ] Bordures lumineuses 1-2px avec couleur primaire glow

### Animations
- [ ] Micro-interactions : 100ms (micro), 200ms (standard), 300ms (transitions)
- [ ] Hover effects sur cartes (scale 1.02 + glow + ombre)
- [ ] Loading states avec ShimmerLoader (pas de CircularProgressIndicator natif)
- [ ] Page transitions slide + fade (300ms)

### Typographie
- [ ] Inter pour texte courant
- [ ] Orbitron pour titres et montants
- [ ] Montants FCFA minimum 20px sur mobile
- [ ] Tailles responsives avec `config.scaleFont()`

### Configuration Dynamique
- [ ] Paramètres thème chargeables depuis API
- [ ] Changements appliqués en temps réel (WebSocket)
- [ ] Logs d'audit pour chaque modification admin
- [ ] Permissions vérifiées côté backend
- [ ] Valeurs par défaut si config non disponible

### Responsivité
- [ ] TOUS les écrans utilisent `ResponsiveBuilder`
- [ ] 17 breakpoints respectés (50px-2300px+)
- [ ] Navigation adaptative (bottom nav → sidebar)
- [ ] Testé sur 3 breakpoints minimum (360px, 768px, 1440px)

---

## 8. Anti-Patterns Interdits

### Design System
- ❌ Utiliser `ElevatedButton` natif au lieu de `NeonButton`
- ❌ Utiliser `Card` native au lieu de `NeonCard`
- ❌ Hardcoder des couleurs (toujours utiliser `NeonColors`)
- ❌ Gradients sur éléments autres que CTA et balance
- ❌ Ombres avec opacité > 0.15
- ❌ Tailles de police fixes sans scaling responsive

### Configuration
- ❌ Hardcoder les paramètres dans le code frontend
- ❌ Permettre modification sans log d'audit
- ❌ Charger configuration une seule fois au démarrage
- ❌ Ignorer les erreurs de chargement (toujours fallback sur defaults)
- ❌ Stocker secrets (API keys) en clair dans la DB

---

## 9. Références

- **Thème néon** : `lib/core/theme/neon_theme.dart`
- **Typographie** : `lib/core/theme/typography.dart`
- **Thème Material** : `lib/core/theme/app_theme.dart`
- **Responsive** : `.qoder/rules/rl_responsive-design.md`
- **Composants** : `.qoder/skills/sk_neon-components.md`
- **Backend config** : `apps/game_hub/lib/game_hub/ui/`

---

**Cette règle est OBLIGATOIRE pour TOUT développement frontend WIWIGA. Les violations seront détectées en code review.**

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 24 Juin 2026  
**Version**: 1.0
