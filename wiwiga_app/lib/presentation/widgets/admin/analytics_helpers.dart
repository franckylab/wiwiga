// ============================================================
// Fichier: analytics_helpers.dart
// Description: Widgets et helpers partagés pour tous les écrans
//              analytics admin — élimine la duplication de code
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import 'empty_state.dart';

// ============================================================
// Constantes partagées
// ============================================================

/// Périodes disponibles pour tous les sélecteurs analytics
const List<String> kAnalyticsPeriods = ['24h', '7d', '30d', '90d'];

/// Labels affichés pour les périodes (localisés FR)
const List<String> kAnalyticsPeriodLabels = ['24h', '7j', '30j', '90j'];

// ============================================================
// Formatage — utilitaires statiques
// ============================================================

/// Formatage monétaire et numérique partagé par tous les écrans analytics
class AnalyticsFormat {
  AnalyticsFormat._();

  static double? _toNumDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Formate un montant en FCFA avec suffixes K/M
  /// Ex: 1500 → "1.5K FCFA", 2500000 → "2.5M FCFA"
  static String amount(dynamic value, {String suffix = 'FCFA'}) {
    if (value == null) return '0 $suffix';
    final n = _toNumDouble(value) ?? 0;
    final abs = n.abs();
    if (abs >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M $suffix';
    if (abs >= 1000) return '${(n / 1000).toStringAsFixed(1)}K $suffix';
    return '${n.toStringAsFixed(0)} $suffix';
  }

  /// Formate un montant avec 2 décimales pour les millions
  static String amountPrecise(dynamic value, {String suffix = 'FCFA'}) {
    if (value == null) return '0 $suffix';
    final n = _toNumDouble(value) ?? 0;
    final abs = n.abs();
    if (abs >= 1000000) return '${(n / 1000000).toStringAsFixed(2)}M $suffix';
    if (abs >= 1000) return '${(n / 1000).toStringAsFixed(1)}K $suffix';
    return '${n.toStringAsFixed(0)} $suffix';
  }

  /// Formate un nombre sans unité (joueurs, parties, etc.)
  static String number(dynamic value) {
    if (value == null) return '0';
    final n = _toNumDouble(value) ?? 0;
    if (n.abs() >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n.abs() >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  /// Convertit une valeur dynamique en double (null-safe)
  static double? toDouble(dynamic value) {
    if (value == null) return null;
    return _toNumDouble(value);
  }

  /// Pourcentage formaté
  static String percent(dynamic value, {int decimals = 1}) {
    if (value == null) return '0%';
    final n = _toNumDouble(value) ?? 0;
    return '${n.toStringAsFixed(decimals)}%';
  }

  /// Date au format DD/MM/YYYY
  static String date(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '-';
    }
  }

  /// Date et heure au format DD/MM/YYYY HH:MM
  static String dateTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  /// Date courte DD/MM
  static String shortDate(String ts) {
    if (ts.isEmpty) return '';
    try {
      final dt = DateTime.parse(ts);
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  /// Temps relatif : « À l'instant », « Il y a 5min », « Il y a 3h », « Il y a 2j »
  /// Accepte dynamic (String, DateTime, null) pour unifier audit, notifications, etc.
  static String relativeTime(dynamic timestamp, {String emptyLabel = 'N/A'}) {
    if (timestamp == null) return emptyLabel;
    final dt = timestamp is DateTime
        ? timestamp
        : DateTime.tryParse(timestamp.toString());
    if (dt == null) return emptyLabel;
    final now = DateTime.now();
    final diff = now.difference(dt.isBefore(now) ? dt : dt.toLocal());
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ============================================================
// Widgets partagés
// ============================================================

/// Sélecteur de période analytics (dropdown dans AppBar)
class AnalyticsPeriodSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const AnalyticsPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: DropdownButton<String>(
        value: value,
        dropdownColor: NeonColors.surface,
        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13),
        underline: const SizedBox(),
        items: List.generate(kAnalyticsPeriods.length, (i) {
          return DropdownMenuItem(
            value: kAnalyticsPeriods[i],
            child: Text(kAnalyticsPeriodLabels[i]),
          );
        }),
        onChanged: onChanged,
      ),
    );
  }
}

/// Titre de section réutilisable
class AnalyticsSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;

  const AnalyticsSectionTitle(this.title, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return Row(
        children: [
          Icon(icon, color: NeonColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Text(
      title,
      style: const TextStyle(
        color: NeonColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Point de légende pour graphiques
class AnalyticsLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const AnalyticsLegendDot(this.color, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

/// Grille responsive de KPI cards — layout adaptatif desktop/mobile
class AnalyticsKpiGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final double desktopRatio;
  final double mobileRatio;

  const AnalyticsKpiGrid({
    super.key,
    required this.children,
    this.desktopColumns = 5,
    this.desktopRatio = 1.4,
    this.mobileRatio = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return AdminResponsiveGrid(
      desktopColumns: desktopColumns,
      desktopRatio: desktopRatio,
      mobileRatio: mobileRatio,
      children: children,
    );
  }
}

/// Grille responsive universelle pour tous les écrans admin
///
/// Adapte automatiquement le nombre de colonnes selon la largeur disponible:
/// - Mobile (<600px): 2 colonnes
/// - Tablette (600-1000px): [desktopColumns] ~/ 2 ou 3 colonnes
/// - Desktop (>1000px): [desktopColumns] colonnes
class AdminResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final double desktopRatio;
  final double mobileRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const AdminResponsiveGrid({
    super.key,
    required this.children,
    this.desktopColumns = 4,
    this.desktopRatio = 1.4,
    this.mobileRatio = 1.2,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int cols;
        final double ratio;
        if (w > 1000) {
          cols = desktopColumns;
          ratio = desktopRatio;
        } else if (w > 600) {
          cols = (desktopColumns / 2).ceil().clamp(2, desktopColumns);
          ratio = desktopRatio;
        } else {
          cols = 2;
          ratio = mobileRatio;
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: ratio,
          children: children,
        );
      },
    );
  }
}

/// Pattern loading/error/content standardisé pour tous les écrans analytics
///
/// Usage:
/// ```dart
/// AnalyticsBody(
///   isLoading: state.isLoading,
///   error: state.error,
///   data: state.data,
///   onRetry: () => notifier.load(),
///   builder: (data) => MyContent(data: data),
/// )
/// ```
class AnalyticsBody extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final dynamic data;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> data) builder;

  const AnalyticsBody({
    super.key,
    required this.isLoading,
    required this.error,
    required this.data,
    required this.onRetry,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && data == null) {
      return const Center(child: CircularProgressIndicator(color: NeonColors.primary));
    }
    if (error != null && data == null) {
      return AdminErrorState(error: error!, onRetry: onRetry);
    }
    return builder((data as Map<String, dynamic>?) ?? {});
  }
}

/// Section de contenu dépliable avec animation fluide
///
/// Utilisé dans les écrans admin pour rendre les sections de contenu
/// collapsibles/expandables avec un effet professionnel.
///
/// Usage:
/// ```dart
/// CollapsibleSection(
///   title: 'Métriques Financières',
///   icon: Icons.account_balance,
///   badge: '5',
///   children: [ ... ],
/// )
/// ```
class CollapsibleSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final String? badge;
  final List<Widget> children;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry padding;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.icon,
    this.badge,
    required this.children,
    this.initiallyExpanded = true,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _heightAnim;
  late final Animation<double> _rotateAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
      value: widget.initiallyExpanded ? 1.0 : 0.0,
    );
    _heightAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _rotateAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_animCtrl.value > 0.5) {
      _animCtrl.reverse();
    } else {
      _animCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? NeonColors.primary.withValues(alpha: 0.3)
                : NeonColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header cliquable
            MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? NeonColors.primary.withValues(alpha: 0.04)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: NeonColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: NeonColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.badge != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NeonColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.badge!,
                            style: const TextStyle(
                              color: NeonColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      AnimatedBuilder(
                        animation: _rotateAnim,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotateAnim.value * 0.5, // ~180°
                            child: child,
                          );
                        },
                        child: const Icon(
                          Icons.expand_more,
                          color: NeonColors.textMuted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Contenu dépliable
            SizeTransition(
              sizeFactor: _heightAnim,
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
