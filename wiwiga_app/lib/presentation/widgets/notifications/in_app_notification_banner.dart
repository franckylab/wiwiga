// ============================================================
// Fichier: in_app_notification_banner.dart
// Description: Bannière basse in-app unifiée (FCM foreground + WebSocket).
//              Remplace les SnackBar ad-hoc : bouton Fermer explicite,
//              suppression serveur optionnelle, action Voir, déduplication.
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-15
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/neon_theme.dart';

/// Données minimales pour afficher la bannière basse.
///
/// Pourquoi un record plutôt que NotificationModel : les deux sources temps
/// réel (FCM `RemoteMessage.data` et WS `notification_created`) n'envoient
/// qu'un sous-ensemble (id/titre/corps/catégorie/priorité). Le record évite
/// de fabriquer un faux modèle complet juste pour un toast.
typedef InAppNotificationData = ({
  int? id,
  String title,
  String body,
  String category,
  String priority,
});

/// Durée d'affichage selon la priorité serveur.
///
/// Pourquoi : une alerte sécurité doit rester lisible plus longtemps qu'une
/// promo, sans pour autant bloquer l'écran (jamais de durée infinie : la
/// bannière reste auto-dismiss + swipe + bouton Fermer).
Duration inAppBannerDurationFor(String priority) {
  switch (priority.toLowerCase()) {
    case 'urgent':
      return const Duration(seconds: 10);
    case 'high':
      return const Duration(seconds: 8);
    case 'low':
      return const Duration(seconds: 5);
    default:
      return const Duration(seconds: 6);
  }
}

/// Couleur d'accent par catégorie (même mapping que l'inbox).
///
/// Pourquoi centralisé ici : la bannière et la liste doivent rester
/// visuellement cohérentes (sécurité = rouge, jetons = vert…).
Color inAppBannerAccentFor(String category) {
  switch (category) {
    case 'security':
      return NeonColors.error;
    case 'transactional':
      return NeonColors.success;
    case 'social':
      return NeonColors.accent;
    case 'game':
      return NeonColors.secondary;
    case 'marketing':
      return NeonColors.tokenGold;
    default:
      return NeonColors.primary;
  }
}

/// Icône par catégorie (même mapping que l'inbox).
IconData inAppBannerIconFor(String category) {
  switch (category) {
    case 'security':
      return Icons.shield_rounded;
    case 'transactional':
      return Icons.monetization_on_rounded;
    case 'social':
      return Icons.people_rounded;
    case 'game':
      return Icons.casino_rounded;
    case 'marketing':
      return Icons.campaign_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

// Déduplication inter-sources : le même événement arrive souvent 2 fois
// (FCM foreground + WS `notification_created`). Sans garde, l'utilisateur
// voit la bannière en double. Fenêtre courte : 2 affichages volontaires
// espacés restent possibles.
int? _lastBannerNotificationId;
String _lastBannerSignature = '';
DateTime? _lastBannerShownAt;
const _bannerDedupWindow = Duration(seconds: 4);

/// Signature de repli quand l'id est absent (FCM sans data, vieux payloads).
String _bannerSignature(InAppNotificationData data) {
  if (data.id != null) return 'id:${data.id}';
  return 't:${data.title}|b:${data.body}';
}

/// Affiche la bannière basse de notification.
///
/// - [onView] : navigation (recommandé : `context.go('/notifications')`
///   ou deep-link sûr). Si nul et [viewRoute] fourni, aucun routage
///   automatique n'est tenté : l'appelant reste maître de la navigation
///   (go_router n'utilise pas le Navigator impératif).
/// - [viewRoute] : route poussée au tap sur le corps et au bouton Voir.
/// - [onDelete] : suppression serveur (bouton poubelle). Absent si `id`
///   inconnu : on masque alors le bouton plutôt que d'afficher une action
///   morte (meilleure pratique : jamais de bouton qui ne fait rien).
/// - [onClosed] : notifie la fermeture manuelle (analytics, optionnel).
///
/// Garanties : remplace la bannière précédente (pas d'empilement), swipe
/// pour rejeter (natif SnackBar), bouton Fermer 48×48 explicite, textes
/// tronqués (pas d'overflow), `NeonColors` uniquement.
void showInAppNotificationBanner(
  BuildContext context, {
  required InAppNotificationData data,
  String? viewRoute,
  VoidCallback? onView,
  Future<void> Function()? onDelete,
  VoidCallback? onClosed,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // Déduplication : ignore le doublon FCM + WS du même événement.
  final signature = _bannerSignature(data);
  final now = DateTime.now();
  final isDuplicate = signature == _lastBannerSignature &&
      _lastBannerShownAt != null &&
      now.difference(_lastBannerShownAt!) < _bannerDedupWindow;
  if (isDuplicate) return;
  _lastBannerSignature = signature;
  _lastBannerNotificationId = data.id;
  _lastBannerShownAt = now;

  final title = data.title.trim().isEmpty ? 'WIWIGA' : data.title.trim();
  final body = data.body.trim();
  final accent = inAppBannerAccentFor(data.category);
  // Capture locale : promeut onDelete en non-nul pour le bouton Supprimer
  // (jamais de `!` : le bouton n'existe que si cette valeur est non-nulle).
  final deleteAction = data.id != null ? onDelete : null;

  // Remplace la bannière précédente : un seul toast visible à la fois
  // (évite l'empilement quand les événements arrivent en rafale).
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Semantics(
        // Annonce la notification aux lecteurs d'écran dès son apparition.
        liveRegion: true,
        label: 'Notification : $title. ${body.isEmpty ? '' : body}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pastille catégorie (cohérente avec l'inbox).
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(
                inAppBannerIconFor(data.category),
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Corps cliquable → Voir (tap principal, cible large).
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onClosed?.call();
                  onView?.call();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: NeonColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NeonColors.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    // Bouton texte Voir : explicite, accessible, 48px de haut.
                    GestureDetector(
                      onTap: () {
                        messenger.hideCurrentSnackBar();
                        onClosed?.call();
                        onView?.call();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Voir',
                          style: TextStyle(
                            color: NeonColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Supprimer (serveur) — visible uniquement si actionnable.
            if (deleteAction != null)
              Semantics(
                button: true,
                label: 'Supprimer cette notification',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    // Ferme d'abord (feedback immédiat), supprime ensuite.
                    messenger.hideCurrentSnackBar();
                    onClosed?.call();
                    try {
                      await deleteAction();
                    } catch (_) {
                      // L'échec est signalé par l'appelant (son contexte),
                      // jamais ici : ce toast est déjà parti.
                    }
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: NeonColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            // Fermer : rejet local uniquement (ne supprime rien côté serveur).
            // Pourquoi deux actions distinctes : Fermer = "masquer ce toast",
            // Supprimer = "effacer de mon inbox". Les confondre fait perdre
            // des notifications importantes (ex. sécurité, gains).
            Semantics(
              button: true,
              label: 'Fermer cette notification',
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onClosed?.call();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.close_rounded,
                    color: NeonColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: NeonColors.surface,
      behavior: SnackBarBehavior.floating,
      // Marge flottante basse : ne masque ni la bottom-nav ni le contenu.
      // Sur tablette/desktop, marges larges pour une bannière centrée ≤ 480px
      // (conforme au pattern modal/tablette du responsive design).
      margin: _bannerMarginFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NeonRadius.medium),
        side: const BorderSide(color: NeonColors.border),
      ),
      // Glow doux : feedback néon sans agressivité (opacité ≤ 0.3).
      elevation: 8,
      duration: inAppBannerDurationFor(data.priority),
      // Swipe natif pour rejeter + bouton Fermer explicite (redondance
      // volontaire : accessibilité + découverte).
      dismissDirection: DismissDirection.horizontal,
    ),
  );
}

/// Marge responsive de la bannière (mobile plein-largeur, desktop centrée).
EdgeInsets _bannerMarginFor(BuildContext context) {
  final width = MediaQuery.widthOf(context);
  if (width >= 900) {
    final side = (width - 480) / 2;
    return EdgeInsets.fromLTRB(side, 8, side, 24);
  }
  return const EdgeInsets.fromLTRB(16, 5, 16, 16);
}

/// Navigation paresseuse : conservé pour compatibilité d'API.
/// La navigation réelle passe par [onView] (go_router côté appelant).
@Deprecated('Passez onView (context.go) au lieu de viewRoute.')
void goToInAppNotification(BuildContext context, String route) {}

/// Masque la bannière en cours (bouton Fermer programmatique).
void hideInAppNotificationBanner(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
}

/// Dernier id affiché (exposé pour tests / déduplication externe).
int? get lastShownInAppNotificationId => _lastBannerNotificationId;

/// Réinitialise l'état de déduplication (tests uniquement).
@visibleForTesting
void resetInAppBannerDedupForTest() {
  _lastBannerNotificationId = null;
  _lastBannerSignature = '';
  _lastBannerShownAt = null;
}
