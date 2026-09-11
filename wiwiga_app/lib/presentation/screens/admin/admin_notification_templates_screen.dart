// ============================================================
// Fichier: admin_notification_templates_screen.dart
// Description: Admin CRUD templates {{variables}} + preview
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

/// Écran admin des templates de notification
class AdminNotificationTemplatesScreen extends ConsumerStatefulWidget {
  const AdminNotificationTemplatesScreen({super.key});

  @override
  ConsumerState<AdminNotificationTemplatesScreen> createState() =>
      _AdminNotificationTemplatesScreenState();
}

class _AdminNotificationTemplatesScreenState
    extends ConsumerState<AdminNotificationTemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  String? _channelFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      _templates = await repo.listNotificationTemplates(channel: _channelFilter);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminTemplates.load');
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
        title: const Text('Templates', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), tooltip: 'Nouveau template', onPressed: () => _showEditDialog(null)),
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
                    child: _templates.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: const AdminEmptyState(
                                icon: Icons.description_outlined,
                                title: 'Aucun template',
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _templates.length,
                            itemBuilder: (context, index) => _buildTemplateCard(_templates[index]),
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

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final isActive = template['is_active'] == true;
    final required = (template['required_variables'] as List<dynamic>?)?.join(', ') ?? '';

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
              Expanded(
                child: Text(
                  '${template['key']}',
                  style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NeonColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${template['channel']} • v${template['version'] ?? 1}',
                  style: const TextStyle(color: NeonColors.accent, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            template['subject'] ?? '',
            style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Text(
            '${template['body_tpl'] ?? ''}',
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (required.isNotEmpty)
            Text(
              'Variables : $required',
              style: const TextStyle(color: NeonColors.textMuted, fontSize: 10),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: isActive,
                activeThumbColor: NeonColors.primary,
                onChanged: (value) => _toggle(template, value),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Aperçu', style: TextStyle(fontSize: 12)),
                onPressed: () => _showPreviewDialog(template),
              ),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                onPressed: () => _showEditDialog(template),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy_outlined, size: 16),
                label: const Text('Cloner v+1', style: TextStyle(fontSize: 12)),
                onPressed: () => _cloneNextVersion(template),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Supprimer', style: TextStyle(fontSize: 12, color: NeonColors.error)),
                onPressed: () => _confirmDelete(template),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Clone en version suivante (versionnage sans écraser l'actif).
  Future<void> _cloneNextVersion(Map<String, dynamic> template) async {
    try {
      final nextVersion = ((template['version'] as num?)?.toInt() ?? 1) + 1;
      await ref.read(adminRepositoryProvider).createNotificationTemplate({
        'key': template['key'],
        'channel': template['channel'],
        'locale': template['locale'] ?? 'fr',
        'version': nextVersion,
        'subject': template['subject'],
        'body_tpl': template['body_tpl'],
        'required_variables': template['required_variables'] ?? [],
        'category': template['category'] ?? 'transactional',
        'default_priority': template['default_priority'] ?? 'normal',
        'action': template['action'],
        'is_active': false,
      });
      if (mounted) context.showSuccess('Version $nextVersion créée (inactive)');
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminTemplates.clone');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }

  /// Suppression avec confirmation (envois passés conservés).
  void _confirmDelete(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Supprimer ?', style: TextStyle(color: NeonColors.textPrimary, fontSize: 14)),
        content: Text(
          'Supprimer le template ${template['key']} (${template['channel']} v${template['version'] ?? 1}) ? Les envois passés sont conservés.',
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(adminRepositoryProvider).deleteNotificationTemplate(
                      (template['id'] as num).toInt(),
                    );
                if (mounted) context.showSuccess('Template supprimé');
                _load();
              } catch (e, st) {
                ErrorHandler.logError(e, st, context: 'AdminTemplates.delete');
                if (mounted) WiwigaSnack.showError(context, e);
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> template, bool value) async {    try {
      await ref.read(adminRepositoryProvider).updateNotificationTemplate(
        (template['id'] as num).toInt(),
        {'is_active': value},
      );
      if (mounted) context.showSuccess(value ? 'Template activé' : 'Template désactivé');
      _load();
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminTemplates.toggle');
      if (mounted) WiwigaSnack.showError(context, e);
    }
  }

  void _showPreviewDialog(Map<String, dynamic> template) {
    final varsController = TextEditingController(text: _sampleVariables(template));
    String? rendered;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.card,
          title: Text('Aperçu : ${template['key']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Variables (une par ligne : cle=valeur)', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: varsController,
                  maxLines: 4,
                  style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12),
                  decoration: const InputDecoration(hintText: 'pseudo=Ali\nmontant=500'),
                ),
                const SizedBox(height: 12),
                if (rendered != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeonColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Text(rendered!, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13)),
                  ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: NeonColors.error, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () async {
                final variables = <String, String>{};
                for (final line in varsController.text.split('\n')) {
                  final parts = line.split('=');
                  if (parts.length == 2) variables[parts[0].trim()] = parts[1].trim();
                }
                try {
                  final result = await ref.read(adminRepositoryProvider).previewNotificationTemplate(
                    (template['id'] as num).toInt(),
                    variables,
                  );
                  setDialogState(() {
                    rendered = '${result['subject'] ?? ''}\n${result['body'] ?? ''}';
                    error = null;
                  });
                } catch (e) {
                  setDialogState(() {
                    rendered = null;
                    error = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: const Text('Rendre'),
            ),
          ],
        ),
      ),
    );
  }

  String _sampleVariables(Map<String, dynamic> template) {
    final required = (template['required_variables'] as List<dynamic>?) ?? [];
    const samples = {'pseudo': 'Ali', 'montant': '500', 'motif': 'gain de partie', 'code': '123456', 'message': 'Message de test', 'resultat': 'Victoire', 'gain': '1000', 'titre': 'Titre de test'};
    return required.map((v) => '$v=${samples[v] ?? 'test'}').join('\n');
  }

  void _showEditDialog(Map<String, dynamic>? template) {
    final tpl = template;
    final isNew = tpl == null;
    final keyController = TextEditingController(text: template?['key'] as String? ?? '');
    final subjectController = TextEditingController(text: template?['subject'] as String? ?? '');
    final bodyController = TextEditingController(text: template?['body_tpl'] as String? ?? '');
    String channel = template?['channel'] as String? ?? 'in_app';
    String category = template?['category'] as String? ?? 'transactional';
    String priority = template?['default_priority'] as String? ?? 'normal';
    final actionController = TextEditingController(text: template?['action'] as String? ?? '');
    List<String> allowedVars = [];
    String? liveRendered;
    String? liveSegments;
    String? liveError;
    bool varsLoaded = false;

    Future<void> loadVars(String key, void Function(void Function()) setState) async {
      if (key.trim().isEmpty) return;
      try {
        final vars = await ref.read(adminRepositoryProvider).getNotificationTemplateVariables(key.trim());
        setState(() => allowedVars = vars);
      } catch (_) {}
    }

    Future<void> renderLive(void Function(void Function()) setState) async {
      try {
        final result = await ref.read(adminRepositoryProvider).previewNotificationBody(
              channel: channel,
              bodyTpl: bodyController.text,
              variables: const {},
            );
        final segments = result['segments'] as Map<String, dynamic>?;
        setState(() {
          liveRendered = result['body'] as String?;
          liveSegments = segments == null
              ? null
              : '${segments['chars']} caractères • ${segments['segments']} segment(s) • ${segments['encoding']}';
          liveError = null;
        });
      } catch (e) {
        setState(() {
          liveRendered = null;
          liveSegments = null;
          liveError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }

    /// Insère {{var}} à la position du curseur dans le corps.
    void insertVariable(String variable, void Function(void Function()) setState) {
      final token = '{{$variable}}';
      final selection = bodyController.selection;
      final text = bodyController.text;
      final offset = selection.isValid ? selection.baseOffset : text.length;
      final updated = text.replaceRange(offset, selection.isValid ? selection.extentOffset : offset, token);
      bodyController.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: offset + token.length),
      );
      setState(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Chargement initial des variables (une fois, clé existante)
          if (!varsLoaded) {
            varsLoaded = true;
            final initialKey = keyController.text.trim();
            if (initialKey.isNotEmpty) {
              loadVars(initialKey, setDialogState);
            }
          }
          return AlertDialog(
          backgroundColor: NeonColors.card,
          title: Text(tpl == null ? 'Nouveau template' : 'Modifier ${tpl['key']}', style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isNew)
                  TextField(
                    controller: keyController,
                    decoration: const InputDecoration(labelText: "Clé d'événement", hintText: 'wallet_credit'),
                    style: const TextStyle(color: NeonColors.textPrimary),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  dropdownColor: NeonColors.surface,
                  decoration: const InputDecoration(labelText: 'Canal'),
                  items: const ['in_app', 'push', 'sms', 'email']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => channel = v ?? 'in_app'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: NeonColors.surface,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: const ['security', 'transactional', 'social', 'game', 'marketing']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'transactional'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  dropdownColor: NeonColors.surface,
                  decoration: const InputDecoration(labelText: 'Priorité par défaut'),
                  items: const ['urgent', 'high', 'normal', 'low']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? 'normal'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: actionController,
                  decoration: const InputDecoration(
                    labelText: 'Action (deep-link)',
                    hintText: '/transactions, /games, /friends… (vide = auto)',
                  ),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(labelText: 'Sujet / Titre'),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Corps ({{variables}})', hintText: '+{{montant}} jetons : {{motif}}'),
                  style: const TextStyle(color: NeonColors.textPrimary),
                ),
                const SizedBox(height: 8),
                // Variables autorisées : tap = insérer dans le corps
                Row(
                  children: [
                    const Expanded(
                      child: Text('Variables autorisées', style: TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: NeonColors.textSecondary),
                      tooltip: 'Recharger (d\u2019après la clé)',
                      onPressed: () => loadVars(keyController.text, setDialogState),
                    ),
                  ],
                ),
                if (allowedVars.isEmpty)
                  const Text(
                    'Aucune variable connue — renseignez la clé puis rechargez.',
                    style: TextStyle(color: NeonColors.textMuted, fontSize: 11),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allowedVars.map((v) {
                      return ActionChip(
                        label: Text('{{$v}}', style: const TextStyle(fontSize: 11)),
                        backgroundColor: NeonColors.surface,
                        side: const BorderSide(color: NeonColors.border),
                        labelStyle: const TextStyle(color: NeonColors.accent),
                        onPressed: () => insertVariable(v, setDialogState),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                // Aperçu live du corps en cours d'édition (+ segments SMS)
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Rendre', style: TextStyle(fontSize: 12)),
                      onPressed: () => renderLive(setDialogState),
                    ),
                    if (liveSegments != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          liveSegments!,
                          style: const TextStyle(color: NeonColors.warning, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                ),
                if (liveRendered != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NeonColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: NeonColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Text(liveRendered!, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12)),
                  ),
                if (liveError != null)
                  Text(liveError!, style: const TextStyle(color: NeonColors.error, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                if (bodyController.text.isEmpty) return;
                try {
                  final repo = ref.read(adminRepositoryProvider);
                  if (tpl == null) {
                    if (keyController.text.isEmpty) return;
                    await repo.createNotificationTemplate({
                      'key': keyController.text.trim(),
                      'channel': channel,
                      'locale': 'fr',
                      'version': 1,
                      'subject': subjectController.text.trim(),
                      'body_tpl': bodyController.text,
                      'category': category,
                      'default_priority': priority,
                      'action': actionController.text.trim().isEmpty ? null : actionController.text.trim(),
                      'is_active': true,
                    });
                    if (mounted) context.showSuccess('Template créé');
                  } else {
                    await repo.updateNotificationTemplate(
                      (tpl['id'] as num).toInt(),
                      {
                        'subject': subjectController.text.trim(),
                        'body_tpl': bodyController.text,
                        'category': category,
                        'default_priority': priority,
                        'action': actionController.text.trim().isEmpty ? null : actionController.text.trim(),
                      },
                    );
                    if (mounted) context.showSuccess('Template mis à jour');
                  }
                  _load();
                } catch (e, st) {
                  ErrorHandler.logError(e, st, context: 'AdminTemplates.save');
                  if (mounted) WiwigaSnack.showError(context, e);
                }
              },
              child: Text(isNew ? 'Créer' : 'Enregistrer'),
            ),
          ],
        );
        },
      ),
    );
  }
}
