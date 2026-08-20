// ============================================================
// Fichier: admin_platform_config_screen.dart
// Description: Configuration centralisée de la plateforme
//              7 catégories: Payment, Security, Registration, Social, Ranking, Gaming, Notification
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../providers/admin_management_provider.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran configuration plateforme centralisée
class AdminPlatformConfigScreen extends ConsumerStatefulWidget {
  const AdminPlatformConfigScreen({super.key});

  @override
  ConsumerState<AdminPlatformConfigScreen> createState() => _AdminPlatformConfigScreenState();
}

class _AdminPlatformConfigScreenState extends ConsumerState<AdminPlatformConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _editingKey;
  final _editController = TextEditingController();

  static const _categoryIcons = {
    'payment': Icons.account_balance_wallet,
    'security': Icons.security,
    'registration': Icons.how_to_reg,
    'social': Icons.people,
    'ranking': Icons.leaderboard,
    'gaming': Icons.sports_esports,
    'notification': Icons.notifications,
  };

  static const _categoryLabels = {
    'payment': 'Paiements',
    'security': 'Sécurité',
    'registration': 'Inscription',
    'social': 'Social & Amis',
    'ranking': 'Classements',
    'gaming': 'Jeux',
    'notification': 'Notifications',
  };

  static const _categoryColors = {
    'payment': NeonColors.success,
    'security': NeonColors.error,
    'registration': NeonColors.accent,
    'social': NeonColors.secondary,
    'ranking': NeonColors.rankDiamond,
    'gaming': NeonColors.primary,
    'notification': NeonColors.warning,
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminPlatformConfigProvider.notifier).loadAll();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = ref.read(adminPlatformConfigProvider);
    if (state.categories.isNotEmpty && _tabController.length != state.categories.length) {
      _initTabController(state.categories.length);
    }
  }

  void _initTabController(int length) {
    _tabController = TabController(length: length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final state = ref.read(adminPlatformConfigProvider);
        if (_tabController.index < state.categories.length) {
          final cat = state.categories[_tabController.index];
          ref.read(adminPlatformConfigProvider.notifier).loadCategory(cat);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminPlatformConfigProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Config. Plateforme', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminPlatformConfigProvider.notifier).loadAll(),
          ),
        ],
      ),
      body: state.isLoading && state.configs.isEmpty
          ? const NeonLoadingSpinner.center()
          : state.error != null && state.configs.isEmpty
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminPlatformConfigProvider.notifier).loadAll())
              : state.categories.isEmpty
                  ? const Center(child: Text('Aucune catégorie', style: TextStyle(color: NeonColors.textSecondary)))
                  : Column(
                      children: [
                        _buildCategoryTabs(state.categories),
                        Expanded(child: _buildCategoryContent(state)),
                      ],
                    ),
    );
  }

  Widget _buildCategoryTabs(List<String> categories) {
    if (_tabController.length != categories.length) {
      _initTabController(categories.length);
    }
    return Container(
      color: NeonColors.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: NeonColors.primary,
        labelColor: NeonColors.primary,
        unselectedLabelColor: NeonColors.textSecondary,
        tabs: categories.map((cat) {
          return Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_categoryIcons[cat] ?? Icons.settings, size: 16),
                const SizedBox(width: 6),
                Text(_categoryLabels[cat] ?? cat, style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryContent(AdminPlatformConfigState state) {
    if (_tabController.index >= state.categories.length) {
      return const SizedBox.shrink();
    }
    final category = state.categories[_tabController.index];
    final configs = state.configs[category] ?? [];
    final color = _categoryColors[category] ?? NeonColors.primary;

    if (configs.isEmpty) {
      return const Center(child: Text('Chargement...', style: TextStyle(color: NeonColors.textSecondary)));
    }

    return RefreshIndicator(
      color: NeonColors.primary,
      onRefresh: () => ref.read(adminPlatformConfigProvider.notifier).loadAll(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: configs.length,
        itemBuilder: (context, index) {
          final config = configs[index];
          return _buildConfigItem(config, category, color);
        },
      ),
    );
  }

  Widget _buildConfigItem(Map<String, dynamic> config, String category, Color color) {
    final key = config['key'] as String;
    final label = config['label'] as String? ?? key;
    final description = config['description'] as String? ?? '';
    final value = config['value']?.toString() ?? config['default_value']?.toString() ?? '';
    final valueType = config['value_type'] as String? ?? 'string';
    final isEditable = config['is_editable'] as bool? ?? true;
    final isEditing = _editingKey == key;

    return Card(
      color: NeonColors.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: NeonColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
                _buildValueTypeBadge(valueType),
                if (isEditable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(isEditing ? Icons.check : Icons.edit, size: 18, color: isEditing ? NeonColors.success : NeonColors.textSecondary),
                    onPressed: () {
                      if (isEditing) {
                        _saveConfig(category, key, _editController.text);
                      } else {
                        setState(() {
                          _editingKey = key;
                          _editController.text = value;
                        });
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            if (isEditing)
              TextField(
                controller: _editController,
                style: const TextStyle(color: NeonColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: NeonColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: NeonColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color)),
                ),
                keyboardType: _getKeyboardType(valueType),
                autofocus: true,
                onSubmitted: (v) => _saveConfig(category, key, v),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NeonColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: NeonColors.border),
                ),
                child: Text(
                  _formatDisplayValue(value, valueType),
                  style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueTypeBadge(String type) {
    final colors = {'boolean': NeonColors.success, 'integer': NeonColors.accent, 'float': NeonColors.secondary, 'string': NeonColors.textSecondary};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (colors[type] ?? NeonColors.textSecondary).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(type, style: TextStyle(color: colors[type] ?? NeonColors.textSecondary, fontSize: 10)),
    );
  }

  void _saveConfig(String category, String key, String value) async {
    final success = await ref.read(adminPlatformConfigProvider.notifier).updateConfig(category, key, value);
    if (mounted) {
      context.showResult(success,
        successMsg: 'Configuration mise à jour',
        errorMsg: 'Erreur de sauvegarde',
      );
      setState(() => _editingKey = null);
    }
  }

  TextInputType _getKeyboardType(String valueType) {
    switch (valueType) {
      case 'integer': return TextInputType.number;
      case 'float': return const TextInputType.numberWithOptions(decimal: true);
      default: return TextInputType.text;
    }
  }

  String _formatDisplayValue(String value, String valueType) {
    if (value.isEmpty) return '(non configuré)';
    switch (valueType) {
      case 'boolean': return value == 'true' ? 'Activé' : 'Désactivé';
      case 'integer':
        final n = int.tryParse(value);
        if (n != null && n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
        return value;
      default: return value;
    }
  }
}
