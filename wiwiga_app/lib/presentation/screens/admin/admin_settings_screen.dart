// ============================================================
// Fichier: admin_settings_screen.dart
// Description: Écran settings système admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';

/// Écran de configuration système
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _settings = {};
  bool _isLoading = true;
  String? _error;

  static const _categories = [
    ('general', 'Général', Icons.settings),
    ('email', 'Email', Icons.email),
    ('storage', 'Stockage', Icons.storage),
    ('notification', 'Notifications', Icons.notifications),
    ('security', 'Sécurité', Icons.security),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    Future.microtask(_loadSettings);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final settings = await ref.read(adminRepositoryProvider).getAllSettings();
      setState(() { _settings = settings; _isLoading = false; });
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminSettings._loadSettings');
      setState(() { _isLoading = false; _error = ErrorHandler.userMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Préférences Admin', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: NeonColors.primary,
          labelColor: NeonColors.primary,
          unselectedLabelColor: NeonColors.textSecondary,
          tabs: _categories.map((c) => Tab(text: c.$2, icon: Icon(c.$3, size: 14))).toList(),
        ),
      ),
      body: _isLoading
          ? const NeonLoadingSpinner.center()
          : _error != null
              ? AdminErrorState(error: _error!, onRetry: _loadSettings)
              : TabBarView(
                  controller: _tabController,
                  children: _categories.map((c) => _CategoryTab(
                    category: c.$1,
                    settings: _settings[c.$1] as List<dynamic>? ?? [],
                    onUpdate: _loadSettings,
                  ),).toList(),
                ),
    );
  }
}

class _CategoryTab extends ConsumerStatefulWidget {
  final String category;
  final List<dynamic> settings;
  final VoidCallback onUpdate;

  const _CategoryTab({required this.category, required this.settings, required this.onUpdate});

  @override
  ConsumerState<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends ConsumerState<_CategoryTab> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final setting in widget.settings) {
      final s = setting as Map<String, dynamic>;
      _controllers[s['key'] as String] = TextEditingController(text: s['value']?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _updateSetting(String key, String value) async {
    try {
      await ref.read(adminRepositoryProvider).updateSetting(key, value);
      widget.onUpdate();
      if (mounted) {
        context.showSuccess('$key mis à jour');
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AdminSettings._updateSetting');
      if (mounted) {
        WiwigaSnack.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.settings.isEmpty) {
      return const Center(child: Text('Aucun paramètre', style: TextStyle(color: NeonColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.settings.length,
      itemBuilder: (context, index) {
        final setting = widget.settings[index] as Map<String, dynamic>;
        final key = setting['key'] as String;
        final value = setting['value']?.toString() ?? '';
        final description = setting['description'] as String?;
        final isBool = value == 'true' || value == 'false';

        if (isBool) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: NeonColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SwitchListTile(
              title: Text(key.replaceAll('_', ' '), style: const TextStyle(color: NeonColors.textPrimary)),
              subtitle: description != null ? Text(description, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)) : null,
              value: value == 'true',
              activeThumbColor: NeonColors.primary,
              onChanged: (v) => _updateSetting(key, v ? 'true' : 'false'),
            ),
          );
        }

        final controller = _controllers[key] ?? TextEditingController(text: value);
        _controllers[key] = controller;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: NeonColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key.replaceAll('_', ' '), style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: NeonColors.textPrimary),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.primary)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.save, color: NeonColors.primary, size: 20),
                      onPressed: () => _updateSetting(key, controller.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
