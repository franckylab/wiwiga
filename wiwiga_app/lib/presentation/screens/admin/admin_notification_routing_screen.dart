// ============================================================
// Fichier: admin_notification_routing_screen.dart
// Description: Admin routage événements → canaux (kill-switch inclus)
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-09
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';

/// Canaux routables avec icônes.
const _routingChannels = [
  ('in_app', 'In-App', Icons.notifications_rounded),
  ('push', 'Push', Icons.phone_android_rounded),
  ('sms', 'SMS', Icons.sms_rounded),
  ('email', 'Email', Icons.email_rounded),
];

/// Écran admin du routage : chaque événement est activable/désactivable
/// et routé vers 1..4 canaux. Désactivé = aucun envoi (même inbox).
class AdminNotificationRoutingScreen extends ConsumerStatefulWidget {
  const AdminNotificationRoutingScreen({super.key});

  @override
  ConsumerState<AdminNotificationRoutingScreen> createState() =>
      _AdminNotificationRoutingScreenState();
}

class _AdminNotificationRoutingScreenState
    extends ConsumerState<AdminNotificationRoutingScreen> {
  List<Map<String, dynamic>> _rules = [];
  bool _isLoading = true;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _rules = await ref.read(adminRepositoryProvider).listNotificationRouting();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminRouting.load');
      if (mounted) WiwigaSnack.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Routage', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const AdminSkeletonList(itemCount: 8)
          : RefreshIndicator(
              color: NeonColors.primary,
              onRefresh: _load,
              child: _rules.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const AdminEmptyState(
                          icon: Icons.alt_route_rounded,
                          title: 'Aucune règle',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rules.length,
                      itemBuilder: (context, index) => _buildRuleCard(_rules[index]),
                    ),
            ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule) {
    final key = rule['event_key'] as String? ?? '';
    final channels = ((rule['channels'] as List<dynamic>?) ?? ['in_app'])
        .map((e) => e.toString())
        .toSet();
    final active = rule['is_active'] != false;
    final customized = rule['customized'] == true;
    final busy = _saving.contains(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? NeonColors.primary.withValues(alpha: 0.3)
              : NeonColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  key,
                  style: const TextStyle(
                    color: NeonColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (customized)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: NeonColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('perso', style: TextStyle(color: NeonColors.accent, fontSize: 10)),
                ),
              const SizedBox(width: 8),
              if (busy)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Switch(
                  value: active,
                  activeThumbColor: NeonColors.primary,
                  onChanged: (value) => _save(key, channels.toList(), value),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _routingChannels.map((channel) {
              final (channelKey, channelLabel, channelIcon) = channel;
              final selected = channels.contains(channelKey);
              return FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(channelIcon, size: 14, color: selected ? NeonColors.primary : NeonColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(channelLabel, style: const TextStyle(fontSize: 11)),
                  ],
                ),
                selected: selected,
                selectedColor: NeonColors.primary.withValues(alpha: 0.2),
                backgroundColor: NeonColors.card,
                side: BorderSide(color: selected ? NeonColors.primary : NeonColors.border),
                onSelected: (!active || busy)
                    ? null
                    : (value) {
                        final next = Set<String>.from(channels);
                        if (value) {
                          next.add(channelKey);
                        } else {
                          next.remove(channelKey);
                        }
                        if (next.isEmpty) {
                          WiwigaSnack.showError(context, 'Au moins 1 canal (ou désactivez l\u2019événement)');
                          return;
                        }
                        _save(key, next.toList(), active);
                      },
              );
            }).toList(),
          ),
          if (!active)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Événement désactivé : aucun envoi (même inbox).',
                style: TextStyle(color: NeonColors.warning, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save(String key, List<String> channels, bool active) async {
    setState(() => _saving.add(key));
    try {
      await ref.read(adminRepositoryProvider).upsertNotificationRouting(
            key,
            channels: channels,
            isActive: active,
          );
      if (mounted) context.showSuccess('Routage $key enregistré');
      await _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminRouting.save');
      if (mounted) WiwigaSnack.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }
}
