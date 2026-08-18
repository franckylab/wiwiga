// ============================================================
// Fichier: admin_notifications_screen.dart
// Description: Écran notifications admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_metrics_provider.dart';

/// Écran des notifications admin
class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminAlertsProvider.notifier).loadNotifications();
      ref.read(adminAlertsProvider.notifier).loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminAlertsProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminAlertsProvider.notifier).loadNotifications(),
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: () => _showBroadcastDialog(),
            tooltip: 'Diffuser un message',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres type
          _buildTypeFilter(),
          // Compteur non-lus
          if (state.unreadNotifications > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: NeonColors.info.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: NeonColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${state.unreadNotifications} notification(s) non lue(s)',
                    style: const TextStyle(color: NeonColors.info, fontSize: 12),
                  ),
                ],
              ),
            ),
          // Contenu
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: NeonColors.primary))
                : state.alerts.isEmpty
                    ? _buildEmpty()
                    : _buildNotificationList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NeonColors.surface,
      child: Row(
        children: [
          _typeChip(null, 'Toutes'),
          const SizedBox(width: 8),
          _typeChip('info', 'Info'),
          const SizedBox(width: 8),
          _typeChip('alert', 'Alerte'),
          const SizedBox(width: 8),
          _typeChip('broadcast', 'Broadcast'),
        ],
      ),
    );
  }

  Widget _typeChip(String? value, String label) {
    final isSelected = _typeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: NeonColors.primary.withValues(alpha: 0.2),
      backgroundColor: NeonColors.card,
      labelStyle: TextStyle(
        color: isSelected ? NeonColors.textPrimary : NeonColors.textSecondary,
        fontSize: 11,
      ),
      side: BorderSide(color: isSelected ? NeonColors.primary : NeonColors.border),
      onSelected: (selected) {
        setState(() => _typeFilter = selected ? value : null);
        ref.read(adminAlertsProvider.notifier).loadNotifications(type: value);
      },
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off, color: NeonColors.textMuted, size: 48),
          SizedBox(height: 12),
          Text('Aucune notification', style: TextStyle(color: NeonColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNotificationList(AdminAlertsState state) {
    final notifications = _typeFilter == null
        ? state.alerts
        : state.alerts.where((a) => a['type'] == _typeFilter).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index] as Map<String, dynamic>;
        final isRead = notif['is_read'] == true;
        final type = notif['type'] ?? 'info';

        IconData iconData;
        Color iconColor;
        switch (type) {
          case 'alert':
            iconData = Icons.warning;
            iconColor = NeonColors.warning;
            break;
          case 'broadcast':
            iconData = Icons.campaign;
            iconColor = NeonColors.info;
            break;
          case 'system':
            iconData = Icons.settings;
            iconColor = NeonColors.textSecondary;
            break;
          default:
            iconData = Icons.info_outline;
            iconColor = NeonColors.primary;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NeonColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRead ? NeonColors.border : NeonColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif['title'] ?? 'Notification',
                      style: TextStyle(
                        color: isRead ? NeonColors.textMuted : NeonColors.textPrimary,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif['message'] ?? '',
                      style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notif['inserted_at']),
                      style: const TextStyle(color: NeonColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (!isRead)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: NeonColors.primary, size: 18),
                  tooltip: 'Marquer comme lu',
                  onPressed: () {
                    final id = notif['id']?.toString();
                    if (id != null) {
                      ref.read(adminAlertsProvider.notifier).markRead(id);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showBroadcastDialog() {
    _titleController.clear();
    _messageController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Diffuser un message', style: TextStyle(color: NeonColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Titre',
                hintText: 'Annonce importante',
              ),
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Contenu du message...',
              ),
              maxLines: 4,
              style: const TextStyle(color: NeonColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_messageController.text.isNotEmpty) {
                try {
                  await ref.read(adminRepositoryProvider).broadcastNotification(
                    _titleController.text.isNotEmpty ? _titleController.text : 'Annonce',
                    _messageController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message diffusé avec succès'), backgroundColor: NeonColors.success),
                    );
                  }
                  ref.read(adminAlertsProvider.notifier).loadNotifications();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: NeonColors.error),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Diffuser'),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp is DateTime ? timestamp : DateTime.tryParse(timestamp.toString());
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Maintenant';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }
}
