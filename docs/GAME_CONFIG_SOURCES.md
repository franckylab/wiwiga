# WIWIGA — Configurations de jeux : sources uniques et ordre de résolution

> Audit 2026-09-09. Principe : **une notion = une table maîtresse**.
> L'écran Vue d'ensemble (`/admin/games-overview`) affiche chaque valeur
> avec sa source ; en cas de doute, il fait foi sur l'état effectif.

## Mises (jetons)

| Niveau | Table | Rôle | Écran |
|---|---|---|---|
| Moteur (validation création) | `game_rules.config.min/max_bet` | **Fait foi** | Règles |
| Moteur (débit) | `token_configs.min_bet_tokens_dice/card` | Seuil technique anti-poussière | Config → Wiga |
| Affichage catalogue | `game_configs.min/max_bet` (+`min_bet_tokens`) | Informatif uniquement | Config. Jeux |
| Coup (jeu responsable) | `platform_configs:gaming.max_bet_per_round` | Plafonne `responsible_gaming_limits.max_bet_amount` | Jeu Responsable |

## Commission

| Niveau | Table | Rôle |
|---|---|---|
| Taux du match | `game_rules.config.commission_rate` | **Fait foi, gelé au démarrage** |
| Catalogue | `game_configs.commission_rate/mode` | Affichage + calcul comptable |
| Remise par tier | `player_level_configs.benefits.bet_discount` | Remise appliquée après |
| Mortes (ne pas utiliser) | `platform_configs:gaming.global_commission_rate`, `system_settings.commission_rate_global` | relues par personne |

## Délais

| Niveau | Table | Rôle |
|---|---|---|
| Tour/suivant/grâce | `game_rules.config.*` (`turn_timeout_seconds=null` = héritage) | **Fait foi par match** |
| Global (déconnexion + repli tour) | `game_timeout_configs.grace_period_seconds` | Repli + déconnexion |
| Matchmaking | `platform_configs:gaming.fallback_timeout_seconds` | File d'attente |
| Session/websocket | `app_feature_configs`, `platform_configs:security.session_timeout_minutes` | Infra (pas de jeu) |

## Limites jeu responsable

Maître = écran **Jeu Responsable** (`platform_configs:gaming`, 7 clés).
L'onglet Jeux de Config Plateforme masque ces clés (bandeau de renvoi).
Perso (`responsible_gaming_limits`) prime, sauf `max_bet` = min(perso, plateforme).
`weekly/monthly_loss_limit` : sans défaut plateforme (= illimité si perso nul).

## Jetons & financier

| Notion | Source unique |
|---|---|
| Taux, mises min dés/cartes, cadeaux on/off | `token_configs` (Config → Wiga) |
| Plafond cadeaux/jour | `platform_configs:payment.daily_gift_limit` (écrit 1× depuis Wiga) |
| Bornes dépôt/retrait, KYC, frais | `platform_configs:payment` (lues par Wallet) |
| Détail par provider (min/max, frais) | `payment_configs` via Config → Paiements |
| Bonus catalogue | `bonuses` (création + édition + toggle) |
| Bonus bienvenue à l'inscription | `platform_configs:registration.welcome_bonus_*` (lu par Auth) |
| XP gagnés / seuils / avantages | `xp_rules` / `player_level_configs` (écrans distincts) |
| Chat amis on/off | `platform_configs:social.enable_friend_chat` |

## Supprimés de l'UI (données conservées)

- Settings `email`/`notification`, platform `notification` → section NOTIFICATIONS.
- Toggles Features PvP/Tournois/Chat/Transferts (non persistés, dont un mensonger).
- `giftFeePercent` 5 % fantôme, `Bonus Retrait 0 %` figé.
- `game_specific_configs` (table orpheline, écriture déjà coupée) : ne pas réutiliser.
- `set_timeout_seconds` (seedé, jamais lu) : ignoré, ne pas étendre.
