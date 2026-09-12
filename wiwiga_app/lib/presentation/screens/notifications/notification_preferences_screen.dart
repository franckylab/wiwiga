// ============================================================
// Fichier: notification_preferences_screen.dart
// Description: Matrice catégories × canaux (sécurité verrouillée)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
// ============================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/notification_provider.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Ordre et libellés des catégories
const _categories = [
  (
    'security',
    'Sécurité',
    'Codes OTP, alertes de compte. Toujours actif.',
    Icons.shield_rounded
  ),
  (
    'transactional',
    'Jetons',
    'Achats, gains, mouvements de jetons.',
    Icons.monetization_on_rounded
  ),
  ('game', 'Jeux', 'Résultats de matchs, revanche.', Icons.casino_rounded),
  ('social', 'Amis', 'Demandes et activité entre amis.', Icons.people_rounded),
  (
    'marketing',
    'Promotions',
    'Bonus et annonces. Désactivable.',
    Icons.campaign_rounded
  ),
];

/// Ordre et libellés des canaux
const _channels = [
  ('in_app', 'In-App', Icons.notifications_rounded),
  ('push', 'Push', Icons.phone_android_rounded),
  ('sms', 'SMS', Icons.sms_rounded),
  ('email', 'Email', Icons.email_rounded),
];

/// Écran des préférences de notification (matrice catégorie × canal)
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  final Set<String> _saving = {};

  // Heures creuses (heure de Douala) : push/sms/email différés, inbox intacte.
  bool _quietEnabled = false;
  int _quietStart = 22;
  int _quietEnd = 7;
  bool _quietLoaded = false;
  bool _quietSaving = false;

  // Activation push de cet appareil (bouton de la carte d'état).
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadQuietHours);
  }

  /// Charge les heures creuses depuis les préférences serveur.
  Future<void> _loadQuietHours() async {
    try {
      final prefs =
          await ref.read(preferencesRepositoryProvider).getPreferences();
      final quiet = prefs['quiet_hours'];
      if (quiet is Map && mounted) {
        setState(() {
          _quietEnabled = quiet['enabled'] == true;
          _quietStart = (quiet['start'] as num?)?.toInt() ?? 22;
          _quietEnd = (quiet['end'] as num?)?.toInt() ?? 7;
          _quietLoaded = true;
        });
      } else if (mounted) {
        setState(() => _quietLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _quietLoaded = true);
    }
  }

  /// Sauvegarde les heures creuses (fusion côté serveur).
  Future<void> _saveQuietHours() async {
    setState(() => _quietSaving = true);
    try {
      await ref.read(preferencesRepositoryProvider).updatePreferences({
        'quiet_hours': {
          'enabled': _quietEnabled,
          'start': _quietStart,
          'end': _quietEnd,
        },
      });
    } catch (_) {
      // Erreur silencieuse : recharge l'état serveur
      await _loadQuietHours();
    } finally {
      if (mounted) setState(() => _quietSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Préférences'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return prefs.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoader(height: 120),
              ),
            ),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 56, color: NeonColors.error,),
                  const SizedBox(height: 12),
                  const Text(
                    'Préférences indisponibles',
                    style:
                        TextStyle(color: NeonColors.textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  NeonButton(
                    text: 'Réessayer',
                    onPressed: () =>
                        ref.invalidate(notificationPreferencesProvider),
                    variant: NeonButtonVariant.primary,
                  ),
                ],
              ),
            ),
            data: (list) => _buildMatrix(list, wide),
          );
        },
      ),
    );
  }

  Widget _buildMatrix(List<NotificationPreferenceModel> list, bool wide) {
    final byKey = {
      for (final p in list) '${p.category}|${p.channel}': p.enabled,
    };

    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: wide ? 64 : 12, vertical: 8),
          child: _buildPushDeviceCard(),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: wide ? 64 : 12, vertical: 8),
          child: _buildQuietHoursCard(),
        ),
        Expanded(
          child: ListView.builder(
            padding:
                EdgeInsets.symmetric(horizontal: wide ? 64 : 12, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final (category, label, hint, icon) = _categories[index];
              return _buildCategoryCard(category, label, hint, icon, byKey);
            },
          ),
        ),
      ],
    );
  }

  /// État push de CET appareil (tient la promesse de l'opt-in :
  /// "Modifiable à tout moment dans Notifications > Préférences").
  /// Affiche l'état réel (y compris "bloqué" avec guidance cadenas)
  /// et permet d'activer / renvoyer le token à tout moment.
  Widget _buildPushDeviceCard() {
    final status = ref.watch(pushDeviceStatusProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        child: status.when(
          loading: () => const Row(
            children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),),
              SizedBox(width: 12),
              Text('Vérification des notifications…',
                  style:
                      TextStyle(color: NeonColors.textSecondary, fontSize: 13),),
            ],
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: _pushDeviceContent,
        ),
      ),
    );
  }

  Widget _pushDeviceContent(PushDeviceStatus s) {
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;
    final String action;
    if (!s.available) {
      icon = Icons.phonelink_erase_rounded;
      color = NeonColors.error;
      title = 'Push indisponible';
      subtitle = s.diagnostic ?? 'Firebase non configuré sur cet appareil.';
      action = 'Réessayer';
    } else if (s.permission == AuthorizationStatus.authorized ||
        s.permission == AuthorizationStatus.provisional) {
      icon = Icons.notifications_active_rounded;
      color = NeonColors.success;
      title = 'Push activées';
      subtitle = 'Cet appareil reçoit les notifications push.';
      action = 'Renvoyer le token';
    } else if (s.permission == AuthorizationStatus.denied) {
      icon = Icons.notifications_off_rounded;
      color = NeonColors.warning;
      title = 'Push bloquées';
      subtitle = pushBlockedHint;
      action = 'J\u2019ai autorisé';
    } else {
      icon = Icons.notifications_none_rounded;
      color = NeonColors.textSecondary;
      title = 'Push non activées';
      subtitle = 'Activez pour recevoir gains et alertes, même app fermée.';
      action = 'Activer';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Notifications sur cet appareil',
                style: TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,),
              ),
            ),
            NeonButton(
              text: action,
              onPressed: _pushBusy ? null : _retryPush,
              variant: NeonButtonVariant.primary,
              height: 40,
              fontSize: 13,
              isLoading: _pushBusy,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold,),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// Bouton de la carte : (ré)active le push puis rafraîchit l'état.
  Future<void> _retryPush() async {
    setState(() => _pushBusy = true);
    try {
      ref.invalidate(pushInitProvider);
      ref.invalidate(pushDeviceStatusProvider);
      final result = await ensurePushEnabled(ref);
      ref.invalidate(pushDeviceStatusProvider);
      if (!mounted) return;
      if (result.ok) {
        WiwigaSnack.showSuccess(context, result.message);
      } else {
        WiwigaSnack.showError(context, result.message);
      }
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  /// Heures creuses personnelles (heure de Douala).
  Widget _buildQuietHoursCard() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined,
                  color: NeonColors.primary, size: 22,),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Heures creuses',
                  style: TextStyle(
                      color: NeonColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,),
                ),
              ),
              if (_quietSaving)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),)
              else
                Switch(
                  value: _quietEnabled,
                  activeThumbColor: NeonColors.primary,
                  onChanged: (value) {
                    setState(() => _quietEnabled = value);
                    _saveQuietHours();
                  },
                ),
            ],
          ),
          const Text(
            'Push, SMS et emails (hors sécurité) différés au matin. L\u2019inbox reste immédiate et silencieuse.',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
          ),
          if (_quietEnabled && _quietLoaded) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildHourPicker(
                        'Début', _quietStart, (h) => _setQuietStart(h),),),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildHourPicker(
                        'Fin', _quietEnd, (h) => _setQuietEnd(h),),),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHourPicker(String label, int hour, void Function(int) onPick) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked.hour);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NeonColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: NeonColors.textSecondary, fontSize: 11,),),
                  Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                        color: NeonColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule_rounded,
                color: NeonColors.textSecondary, size: 18,),
          ],
        ),
      ),
    );
  }

  void _setQuietStart(int hour) {
    setState(() => _quietStart = hour);
    _saveQuietHours();
  }

  void _setQuietEnd(int hour) {
    setState(() => _quietEnd = hour);
    _saveQuietHours();
  }

  Widget _buildCategoryCard(
    String category,
    String label,
    String hint,
    IconData icon,
    Map<String, bool> byKey,
  ) {
    final locked = category == 'security';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeonCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: NeonColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (locked)
                  const Icon(Icons.lock_outline_rounded,
                      color: NeonColors.textSecondary, size: 16,),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(
                  color: NeonColors.textSecondary, fontSize: 12,),
            ),
            const SizedBox(height: 8),
            ..._channels.map((channel) {
              final (channelKey, channelLabel, channelIcon) = channel;
              final mapKey = '$category|$channelKey';
              final enabled = byKey[mapKey] ?? true;
              final busy = _saving.contains(mapKey);
              final interactive = !locked && !busy;

              // Row custom (pas de ListTile : splash ink invisible sous NeonCard)
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(channelIcon,
                        color: NeonColors.textSecondary, size: 20,),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channelLabel,
                        style: const TextStyle(
                            color: NeonColors.textPrimary, fontSize: 14,),
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: locked ? true : enabled,
                        activeThumbColor: NeonColors.primary,
                        onChanged: interactive
                            ? (value) => _toggle(category, channelKey, value)
                            : null,
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(String category, String channel, bool value) async {
    final mapKey = '$category|$channel';
    setState(() => _saving.add(mapKey));
    try {
      await ref.read(notificationRepositoryProvider).updatePreference(
            category: category,
            channel: channel,
            enabled: value,
          );
      ref.invalidate(notificationPreferencesProvider);
    } catch (_) {
      // Erreur silencieuse : l'état serveur est rechargé ci-dessous
      ref.invalidate(notificationPreferencesProvider);
    } finally {
      if (mounted) setState(() => _saving.remove(mapKey));
    }
  }
}
