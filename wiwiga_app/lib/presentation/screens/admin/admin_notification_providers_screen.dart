// ============================================================
// Fichier: admin_notification_providers_screen.dart
// Description: Admin CRUD providers multi-canaux + test connexion
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-09-08
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

/// Écran admin des providers de notification (config centralisée)
class AdminNotificationProvidersScreen extends ConsumerStatefulWidget {
  const AdminNotificationProvidersScreen({super.key});

  @override
  ConsumerState<AdminNotificationProvidersScreen> createState() =>
      _AdminNotificationProvidersScreenState();
}

class _AdminNotificationProvidersScreenState
    extends ConsumerState<AdminNotificationProvidersScreen> {
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;
  String? _channelFilter;
  final _recipientController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      _providers = await repo.listNotificationProviders(channel: _channelFilter);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminProviders.load');
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
        title: const Text('Canaux & Providers', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter un provider',
            onPressed: _showCreateDialog,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Installer les défauts',
            onPressed: _seedDefaults,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChannelFilter(),
          Expanded(
            child: _isLoading
                ? const AdminSkeletonList(itemCount: 6)
                : RefreshIndicator(
                    color: NeonColors.primary,
                    onRefresh: _load,
                    child: _providers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: const AdminEmptyState(
                                icon: Icons.hub_outlined,
                                title: 'Aucun provider',
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _providers.length,
                            itemBuilder: (context, index) => _buildProviderCard(_providers[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelFilter() {
    const channels = [null, 'in_app', 'push', 'sms', 'email'];
    const labels = ['Tous', 'In-App', 'Push', 'SMS', 'Email'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: NeonColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(channels.length, (i) {
            final selected = _channelFilter == channels[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i]),
                selected: selected,
                selectedColor: NeonColors.primary.withValues(alpha: 0.2),
                backgroundColor: NeonColors.card,
                labelStyle: TextStyle(
                  color: selected ? NeonColors.textPrimary : NeonColors.textSecondary,
                  fontSize: 11,
                ),
                side: BorderSide(color: selected ? NeonColors.primary : NeonColors.border),
                onSelected: (_) {
                  setState(() => _channelFilter = channels[i]);
                  _load();
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    final isActive = provider['is_active'] == true;
    final health = provider['last_health_status'] as String? ?? 'unchecked';
    final healthColor = health == 'healthy'
        ? NeonColors.success
        : health == 'down'
            ? NeonColors.error
            : NeonColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? NeonColors.primary.withValues(alpha: 0.3) : NeonColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isActive ? NeonColors.success : NeonColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider['display_name'] ?? provider['name'] ?? 'Provider',
                  style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              // Badge santé
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(health, style: TextStyle(color: healthColor, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${provider['channel']} • ${provider['name']} • priorité ${provider['priority'] ?? 100}',
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11),
          ),
          // Couverture config (clés renseignées • secrets configurés)
          if ((provider['config_keys'] as num?) != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                _CoverageChip(
                  icon: Icons.settings_outlined,
                  label: '${provider['config_keys']} champs',
                  color: (provider['config_keys'] as num) > 0 ? NeonColors.accent : NeonColors.textMuted,
                ),
                const SizedBox(width: 6),
                _CoverageChip(
                  icon: Icons.lock_outline_rounded,
                  label: '${provider['secrets_set'] ?? 0} secrets',
                  color: (provider['secrets_set'] as num? ?? 0) > 0 ? NeonColors.success : NeonColors.warning,
                ),
              ],
            ),
          ],
          if (provider['last_error'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '${provider['last_error']}',
              style: const TextStyle(color: NeonColors.error, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              // Toggle activation
              Switch(
                value: isActive,
                activeThumbColor: NeonColors.primary,
                onChanged: (value) => _toggle(provider, value),
              ),
              const Spacer(),
              // Configurer (clés API, sender ID...)
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Configurer', style: TextStyle(fontSize: 12)),
                onPressed: () => _showConfigDialog(provider),
              ),
              // Santé (sans envoi)
              TextButton.icon(
                icon: const Icon(Icons.monitor_heart_outlined, size: 16),
                label: const Text('Santé', style: TextStyle(fontSize: 12)),
                onPressed: () => _checkHealth(provider),
              ),
              // Test connexion
              TextButton.icon(
                icon: const Icon(Icons.wifi_tethering, size: 16),
                label: const Text('Tester', style: TextStyle(fontSize: 12)),
                onPressed: () => _showTestDialog(provider),
              ),
              // Supprimer
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: NeonColors.error),
                tooltip: 'Supprimer',
                onPressed: () => _confirmDelete(provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> provider, bool value) async {
    try {
      await ref.read(adminRepositoryProvider).updateNotificationProvider(
        (provider['id'] as num).toInt(),
        {'is_active': value},
      );
      if (mounted) context.showSuccess(value ? 'Provider activé' : 'Provider désactivé');
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminProviders.toggle');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }

  void _showTestDialog(Map<String, dynamic> provider) {
    _recipientController.clear();
    final channel = provider['channel'] as String? ?? '';
    final hint = channel == 'sms'
        ? '+2376XXXXXXXX'
        : channel == 'email'
            ? 'test@exemple.com'
            : channel == 'push'
                ? 'Token FCM d\u2019un appareil connecté (login Android, table device_tokens)'
                : 'Token ou identifiant test';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: Text('Tester ${provider['display_name'] ?? provider['name']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 15)),
        content: TextField(
          controller: _recipientController,
          decoration: InputDecoration(labelText: 'Destinataire test', hintText: hint),
          style: const TextStyle(color: NeonColors.textPrimary),
          keyboardType: channel == 'email' ? TextInputType.emailAddress : TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              // Espaces seuls = vide (sinon 422 recipient_required côté API)
              if (_recipientController.text.trim().isEmpty) return;
              try {
                final result = await ref.read(adminRepositoryProvider).testNotificationProvider(
                  (provider['id'] as num).toInt(),
                  _recipientController.text.trim(),
                );
                if (mounted) context.showSuccess('${result['detail'] ?? 'Test effectué'}');
              } catch (e, st) {
                ErrorHandler.logError(e, st, context: 'AdminProviders.test');
                if (mounted) WiwigaSnack.showError(context, e);
              }
              _load();
            },
            child: const Text('Envoyer test'),
          ),
        ],
      ),
    );
  }

  /// Éditeur de configuration : schéma depuis le backend, secrets masqués.
  /// Un secret laissé vide conserve la valeur existante.
  Future<void> _showConfigDialog(Map<String, dynamic> provider) async {
    final id = (provider['id'] as num).toInt();
    List<Map<String, dynamic>> fields = [];
    bool loading = true;
    String? error;

    try {
      final result = await ref.read(adminRepositoryProvider).getNotificationProviderConfig(id);
      fields = ((result['fields'] as List<dynamic>?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminProviders.config.load');
      error = e.toString().replaceFirst('Exception: ', '');
    }
    loading = false;

    if (!mounted) return;

    final controllers = <String, TextEditingController>{
      for (final f in fields)
        f['key'] as String: TextEditingController(text: (f['value'] as String?) ?? ''),
    };

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: NeonColors.card,
            title: Text(
              'Config : ${provider['display_name'] ?? provider['name']}',
              style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loading)
                      const AdminSkeletonList(itemCount: 3)
                    else if (error != null)
                      Text(error, style: const TextStyle(color: NeonColors.error, fontSize: 12))
                    else if (fields.isEmpty)
                      const Text(
                        'Aucun champ connu pour ce provider.',
                        style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
                      )
                    else
                      ...fields.map((field) {
                        final key = field['key'] as String;
                        final sensitive = field['sensitive'] == true;
                        final isSet = field['set'] == true;
                        final controller = controllers[key]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (field['label'] as String?) ?? key,
                                      style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (sensitive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (isSet ? NeonColors.success : NeonColors.warning).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isSet ? 'configuré' : 'non défini',
                                        style: TextStyle(
                                          color: isSet ? NeonColors.success : NeonColors.warning,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: controller,
                                obscureText: sensitive,
                                maxLines: (field['multiline'] == true) ? 5 : 1,
                                style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: sensitive
                                      ? (isSet ? 'Laisser vide pour conserver' : 'À renseigner')
                                      : (field['help'] as String?) ?? key,
                                  hintStyle: const TextStyle(fontSize: 11),
                                ),
                              ),
                              // Aperçu non secret de la valeur enregistrée
                              // (ex. compte de service FCM : jamais la clé).
                              if (sensitive && (field['hint'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.verified_outlined, size: 12, color: NeonColors.success),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        field['hint'] as String,
                                        style: const TextStyle(color: NeonColors.success, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              if (!loading && error == null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final config = <String, dynamic>{
                      for (final f in fields) f['key'] as String: controllers[f['key']]!.text.trim(),
                    };
                    try {
                      await ref.read(adminRepositoryProvider).updateNotificationProviderConfig(id, config);
                      if (mounted) context.showSuccess('Configuration enregistrée (secrets chiffrés)');
                      _load();
                    } catch (e, st) {
                      ErrorHandler.logError(e, st, context: 'AdminProviders.config.save');
                      if (mounted) WiwigaSnack.showError(context, e);
                    } finally {
                      for (final c in controllers.values) {
                        c.dispose();
                      }
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Santé sans envoi (credentials, connectivité) + refresh du badge.
  Future<void> _checkHealth(Map<String, dynamic> provider) async {
    try {
      final result = await ref.read(adminRepositoryProvider).checkNotificationProviderHealth(
            (provider['id'] as num).toInt(),
          );
      if (mounted) {
        context.showSuccess('${result['status'] ?? 'vérifié'} : ${result['detail'] ?? ''}');
      }
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminProviders.health');
      if (mounted) WiwigaSnack.showError(context, e);
      _load();
    }
  }

  /// Suppression avec confirmation (logs passés conservés).
  void _confirmDelete(Map<String, dynamic> provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Supprimer ?', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14)),
        content: Text(
          'Supprimer ${provider['display_name'] ?? provider['name']} ? Les logs passés sont conservés.',
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).deleteNotificationProvider(
                      (provider['id'] as num).toInt(),
                    );
                if (mounted) context.showSuccess('Provider supprimé');
                _load();
              } catch (e, st) {
                ErrorHandler.logError(e, st, context: 'AdminProviders.delete');
                if (mounted) WiwigaSnack.showError(context, e);
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {    final nameController = TextEditingController();
    final displayController = TextEditingController();
    String channel = 'sms';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.card,
          title: const Text('Nouveau provider', style: TextStyle(color: NeonColors.textPrimary, fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  dropdownColor: NeonColors.surface,
                  decoration: const InputDecoration(labelText: 'Canal'),
                  items: const ['push', 'sms', 'email']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => channel = v ?? 'sms'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nom technique', hintText: 'orange_cm'),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayController,
                  decoration: const InputDecoration(labelText: 'Nom affiché', hintText: 'Orange SMS Cameroun'),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                if (nameController.text.isEmpty) return;
                try {
                  final created = await ref.read(adminRepositoryProvider).createNotificationProvider({
                    'channel': channel,
                    'name': nameController.text.trim(),
                    'display_name': displayController.text.isEmpty ? nameController.text.trim() : displayController.text.trim(),
                    'is_active': false,
                    'priority': 50,
                    'config': {},
                  });
                  if (mounted) context.showSuccess('Provider créé — renseignez sa configuration');
                  await _load();
                  // Enchaîne directement sur la configuration (clés, sender...)
                  if (mounted && created['id'] != null) {
                    final fresh = _providers.cast<Map<String, dynamic>?>().firstWhere(
                          (p) => p != null && (p['id'] as num?)?.toInt() == (created['id'] as num).toInt(),
                          orElse: () => null,
                        );
                    if (fresh != null && mounted) _showConfigDialog(fresh);
                  }
                } catch (e, st) {
                  ErrorHandler.logError(e, st, context: 'AdminProviders.create');
                  if (mounted) WiwigaSnack.showError(context, e);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seedDefaults() async {
    try {
      final result = await ref.read(adminRepositoryProvider).seedNotificationDefaults();
      if (mounted) context.showSuccess('${result['providers'] ?? 6} providers, ${result['templates'] ?? 8} templates');
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminProviders.seed');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }
}

/// Pastille de couverture config (clés/secrets renseignés).
class _CoverageChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CoverageChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}
