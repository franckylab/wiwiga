// ============================================================
// Fichier: admin_game_config_screen.dart
// Description: Écran configuration des jeux (commission, mises, limites)
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/neon_theme.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../providers/admin_management_provider.dart';

/// Écran configuration des jeux
class AdminGameConfigScreen extends ConsumerStatefulWidget {
  const AdminGameConfigScreen({super.key});

  @override
  ConsumerState<AdminGameConfigScreen> createState() => _AdminGameConfigScreenState();
}

class _AdminGameConfigScreenState extends ConsumerState<AdminGameConfigScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminGameConfigManagementProvider.notifier).loadConfigs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminGameConfigManagementProvider);

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text('Règles & Config. Jeux'),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(),
            tooltip: 'Ajouter une configuration',
          ),
        ],
      ),
      body: state.isLoading
          ? const AdminSkeletonList(itemCount: 4)
          : state.error != null
              ? AdminErrorState(error: state.error!, onRetry: () => ref.read(adminGameConfigManagementProvider.notifier).loadConfigs())
              : _buildContent(state),
    );
  }

  Widget _buildContent(AdminGameConfigState state) {
    if (state.configs.isEmpty) {
      return AdminEmptyState(
        icon: Icons.sports_esports,
        title: 'Aucune configuration de jeu',
        actionLabel: 'Créer une configuration',
        actionIcon: Icons.add,
        onAction: () => _showCreateDialog(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(adminGameConfigManagementProvider.notifier).loadConfigs(),
      color: NeonColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.configs.length,
        itemBuilder: (context, index) {
          final config = state.configs[index] as Map<String, dynamic>;
          return _buildConfigCard(config);
        },
      ),
    );
  }

  Widget _buildConfigCard(Map<String, dynamic> config) {
    final gameType = config['game_type'] as String? ?? '';
    final commissionRate = ((config['commission_rate'] as num?)?.toDouble() ?? 0) * 100;
    final minBet = (config['min_bet'] as num?)?.toInt() ?? 0;
    final maxBet = (config['max_bet'] as num?)?.toInt() ?? 0;
    final maxPlayers = config['max_players'] as int? ?? 0;
    final isEnabled = config['is_enabled'] as bool? ?? true;
    final colors = [NeonColors.primary, NeonColors.secondary, NeonColors.accent, NeonColors.success, NeonColors.info];
    final color = colors[gameType.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isEnabled ? color.withValues(alpha: 0.3) : NeonColors.border),
        // Opacité réduite si désactivé
        // opacity: isEnabled ? 1.0 : 0.6, // Note: Container doesn't have opacity, use color adjustments
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.sports_esports, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gameType.toUpperCase(), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
                      if (!isEnabled) const Text('Désactivé', style: TextStyle(color: NeonColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isEnabled,
                onChanged: (value) {
                  ref.read(adminGameConfigManagementProvider.notifier).updateConfig(
                    gameType,
                    {'is_enabled': value},
                  );
                },
                activeThumbColor: NeonColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildConfigField('Commission', '${commissionRate.toStringAsFixed(1)}%', Icons.percent, color)),
              const SizedBox(width: 8),
              Expanded(child: _buildConfigField('Mise Min', '$minBet wiga', Icons.arrow_downward, NeonColors.success)),
              const SizedBox(width: 8),
              Expanded(child: _buildConfigField('Mise Max', '$maxBet wiga', Icons.arrow_upward, NeonColors.secondary)),
              const SizedBox(width: 8),
              Expanded(child: _buildConfigField('Max Joueurs', '$maxPlayers', Icons.people, NeonColors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          // Paramètres spécifiques du jeu
          if (_getSettings(config).isNotEmpty) ...[
            _buildSettingsBadges(config, color),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showEditDialog(config),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Modifier'),
              style: TextButton.styleFrom(foregroundColor: color),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getSettings(Map<String, dynamic> config) {
    final raw = config['settings'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Widget _buildSettingsBadges(Map<String, dynamic> config, Color color) {
    final settings = _getSettings(config);
    if (settings.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: settings.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${e.key}: ${e.value}',
            style: TextStyle(color: color, fontSize: 10, fontFamily: 'Inter'),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfigField(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: NeonColors.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> config) {
    final gameType = config['game_type'] as String? ?? '';
    final commissionRate = ((config['commission_rate'] as num?)?.toDouble() ?? 0) * 100;
    final minBet = (config['min_bet'] as num?)?.toInt() ?? 100;
    final maxBet = (config['max_bet'] as num?)?.toInt() ?? 100000;
    final maxPlayers = config['max_players'] as int? ?? 4;
    final settings = _getSettings(config);

    final commCtrl = TextEditingController(text: commissionRate.toStringAsFixed(1));
    final minBetCtrl = TextEditingController(text: minBet.toString());
    final maxBetCtrl = TextEditingController(text: maxBet.toString());
    final maxPlayersCtrl = TextEditingController(text: maxPlayers.toString());
    final settingsCtrl = TextEditingController(
      text: settings.entries.map((e) => '${e.key}=${e.value}').join('\n'),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: Text('Config ${gameType.toUpperCase()}', style: const TextStyle(color: NeonColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(commCtrl, 'Commission (%)', Icons.percent),
              const SizedBox(height: 12),
              _buildTextField(minBetCtrl, 'Mise Min (wiga)', Icons.arrow_downward),
              const SizedBox(height: 12),
              _buildTextField(maxBetCtrl, 'Mise Max (wiga)', Icons.arrow_upward),
              const SizedBox(height: 12),
              _buildTextField(maxPlayersCtrl, 'Max Joueurs', Icons.people),
              const SizedBox(height: 16),
              const Text(
                'Paramètres spécifiques (clé=valeur, un par ligne)',
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 11, fontFamily: 'Inter'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: settingsCtrl,
                style: const TextStyle(color: NeonColors.textPrimary, fontFamily: 'Inter', fontSize: 12),
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'tie_rule=replay\nturn_order=rotating\ndice_faces=6',
                  hintStyle: const TextStyle(color: NeonColors.textMuted, fontSize: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: NeonColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: NeonColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validation
              final comm = double.tryParse(commCtrl.text) ?? 5;
              final minB = int.tryParse(minBetCtrl.text) ?? 100;
              final maxB = int.tryParse(maxBetCtrl.text) ?? 100000;
              final maxP = int.tryParse(maxPlayersCtrl.text) ?? 4;
              if (comm < 0 || comm > 100) {
                context.showError('Commission doit être entre 0% et 100%');
                return;
              }
              if (minB < 0 || maxB < minB) {
                context.showError('Mise Min doit être >= 0 et <= Mise Max');
                return;
              }
              if (maxP < 2 || maxP > 20) {
                context.showError('Max Joueurs doit être entre 2 et 20');
                return;
              }
              Navigator.pop(ctx);
              final parsedSettings = _parseSettings(settingsCtrl.text);
              final success = await ref.read(adminGameConfigManagementProvider.notifier).updateConfig(gameType, {
                'commission_rate': comm / 100,
                'min_bet': minB,
                'max_bet': maxB,
                'max_players': maxP,
                'settings': parsedSettings,
              });
              if (mounted) {
                context.showResult(success,
                  successMsg: 'Configuration $gameType mise à jour',
                  errorMsg: 'Erreur de sauvegarde',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  /// Parse "clé=valeur\nclé2=valeur2" en Map
  Map<String, dynamic> _parseSettings(String text) {
    final result = <String, dynamic>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.contains('=')) continue;
      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        // Tenter de parser en numérique
        if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else if (double.tryParse(value) != null) {
          result[key] = double.parse(value);
        } else if (value == 'true' || value == 'false') {
          result[key] = value == 'true';
        } else {
          result[key] = value;
        }
      }
    }
    return result;
  }

  void _showCreateDialog() {
    final typeCtrl = TextEditingController();
    final commCtrl = TextEditingController(text: '5.0');
    final minBetCtrl = TextEditingController(text: '100');
    final maxBetCtrl = TextEditingController(text: '100000');
    final maxPlayersCtrl = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: const Text('Nouvelle Configuration', style: TextStyle(color: NeonColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(typeCtrl, 'Type de jeu', Icons.sports_esports),
              const SizedBox(height: 12),
              _buildTextField(commCtrl, 'Commission (%)', Icons.percent),
              const SizedBox(height: 12),
              _buildTextField(minBetCtrl, 'Mise Min (wiga)', Icons.arrow_downward),
              const SizedBox(height: 12),
              _buildTextField(maxBetCtrl, 'Mise Max (wiga)', Icons.arrow_upward),
              const SizedBox(height: 12),
              _buildTextField(maxPlayersCtrl, 'Max Joueurs', Icons.people),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final type = typeCtrl.text.trim();
              if (type.isEmpty) {
                context.showError('Le type de jeu est requis');
                return;
              }
              final comm = double.tryParse(commCtrl.text) ?? 5;
              final minB = int.tryParse(minBetCtrl.text) ?? 100;
              final maxB = int.tryParse(maxBetCtrl.text) ?? 100000;
              final maxP = int.tryParse(maxPlayersCtrl.text) ?? 4;
              if (comm < 0 || comm > 100 || minB < 0 || maxB < minB || maxP < 2) {
                context.showError('Valeurs invalides. Vérifiez les champs.');
                return;
              }
              Navigator.pop(ctx);
              final success = await ref.read(adminGameConfigManagementProvider.notifier).createConfig({
                'game_type': type,
                'commission_rate': comm / 100,
                'min_bet': minB,
                'max_bet': maxB,
                'max_players': maxP,
              });
              if (mounted) {
                context.showResult(success,
                  successMsg: 'Configuration $type créée',
                  errorMsg: 'Erreur de création',
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: NeonColors.textPrimary),
      keyboardType: label.contains('%') || label.contains('wiga') || label.contains('Joueurs')
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonColors.textSecondary),
        prefixIcon: Icon(icon, color: NeonColors.primary, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: NeonColors.primary),
        ),
      ),
    );
  }
}
