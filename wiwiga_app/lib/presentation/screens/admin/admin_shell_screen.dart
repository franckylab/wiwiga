// ============================================================
// Fichier: admin_shell_screen.dart
// Description: Shell de navigation admin avec sidebar/bottom nav
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../providers/admin_ws_provider.dart';
import '../../widgets/admin/alert_badge.dart';
import '../../widgets/admin/admin_search_command.dart';

/// Shell de navigation admin avec sidebar et badge notifications
class AdminShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  final bool _isSidebarVisible = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminAlertsProvider.notifier).loadUnreadCount();
      ref.read(adminWsProvider.notifier).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsState = ref.watch(adminAlertsProvider);
    final wsState = ref.watch(adminWsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: NeonColors.background,
      body: Row(
        children: [
          // Sidebar (desktop) ou Drawer (mobile)
          if (isDesktop && _isSidebarVisible) _buildSidebar(),
          // Contenu principal
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(alertsState, wsState, isDesktop),
                // Contenu
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
      // Bottom nav pour mobile
      bottomNavigationBar: !isDesktop ? _buildBottomNav() : null,
    );
  }

  Widget _buildHeader(AdminAlertsState alertsState, AdminWsState wsState, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(bottom: BorderSide(color: NeonColors.border)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: NeonColors.textPrimary),
              onPressed: () => _showMobileDrawer(),
            ),
          const Text(
            'WIWIGA Admin',
            style: TextStyle(
              color: NeonColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Bouton recherche globale
          IconButton(
            icon: const Icon(Icons.search, color: NeonColors.textSecondary, size: 20),
            onPressed: () => showAdminSearch(context),
            tooltip: 'Rechercher (Ctrl+K)',
          ),
          const SizedBox(width: 4),
          // Indicateur WebSocket
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: wsState.status == AdminWsStatus.connected
                  ? Colors.green
                  : wsState.status == AdminWsStatus.reconnecting
                      ? Colors.orange
                      : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Badge notifications
          AdminAlertBadge(
            count: alertsState.unreadNotifications,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined, color: NeonColors.textSecondary),
              onPressed: () => context.go('/admin/notifications'),
            ),
          ),
          const SizedBox(width: 8),
          // Profil admin + Logout
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            color: NeonColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'logout') _confirmLogout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Profil', style: TextStyle(color: NeonColors.textPrimary))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Déconnexion', style: TextStyle(color: Colors.red))),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: NeonColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.admin_panel_settings, color: NeonColors.primary, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Admin',
                    style: TextStyle(color: NeonColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: NeonColors.primary, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: TextStyle(color: NeonColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/');
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(right: BorderSide(color: NeonColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // -- Principal --
          _navItem(Icons.dashboard_outlined, 'Dashboard', '/admin', currentPath),
          _navItem(Icons.bar_chart, 'Métriques', '/admin/metrics', currentPath),
          _navItem(Icons.people, 'Utilisateurs', '/admin/users', currentPath),
          _navItem(Icons.videogame_asset, 'Parties Live', '/admin/games-live', currentPath),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text('ANALYTICS', style: TextStyle(color: NeonColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          _navItem(Icons.monetization_on, 'Revenue Analytics', '/admin/analytics/revenue', currentPath),
          _navItem(Icons.people_outline, 'Player Analytics', '/admin/analytics/players', currentPath),
          _navItem(Icons.sports_esports, 'Game Analytics', '/admin/analytics/games', currentPath),
          _navItem(Icons.swap_horiz, 'Flux Monétaire', '/admin/analytics/monetary-flow', currentPath),
          _navItem(Icons.account_tree, 'Player Wealth', '/admin/analytics/wealth', currentPath),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text('CONFIGURATION', style: TextStyle(color: NeonColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          _navItem(Icons.tune, 'Game Config', '/admin/game-config', currentPath),
          _navItem(Icons.settings_suggest, 'Plateforme', '/admin/platform-config', currentPath),
          _navItem(Icons.emoji_events, 'Progression', '/admin/player-progression', currentPath),
          _navItem(Icons.card_giftcard, 'Bonus & Promos', '/admin/bonuses', currentPath),
          _navItem(Icons.assessment, 'Rapports', '/admin/reports', currentPath),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text('OPERATIONS', style: TextStyle(color: NeonColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          _navItem(Icons.settings, 'Configuration', '/admin/config', currentPath),
          _navItem(Icons.monitor_heart, 'Monitoring', '/admin/monitoring', currentPath),
          _navItem(Icons.security, 'Sécurité', '/admin/security', currentPath),
          _navItem(Icons.shield, 'Jeu Responsable', '/admin/responsible-gaming', currentPath),
          _navItem(Icons.people_alt, 'CRM', '/admin/crm', currentPath),
          _navItem(Icons.account_balance, 'Réconciliation', '/admin/reconciliation', currentPath),
          _navItem(Icons.tune, 'Settings', '/admin/settings', currentPath),
          _navItem(Icons.notifications_outlined, 'Notifications', '/admin/notifications', currentPath),
          _navItem(Icons.history, 'Audit', '/admin/audit', currentPath),
          const Divider(color: NeonColors.border, height: 24),
          _navItem(Icons.notifications_active, 'Alertes', '/admin/alerts', currentPath),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, String path, String currentPath) {
    final isActive = currentPath == path || (path != '/admin' && currentPath.startsWith(path));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(path),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? NeonColors.primary.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isActive ? const Border(left: BorderSide(color: NeonColors.primary, width: 3)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? NeonColors.primary : NeonColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? NeonColors.primary : NeonColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(top: BorderSide(color: NeonColors.border)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavItem(Icons.dashboard_outlined, 'Dashboard', '/admin', currentPath),
            _bottomNavItem(Icons.bar_chart, 'Métriques', '/admin/metrics', currentPath),
            _bottomNavItem(Icons.videogame_asset, 'Live', '/admin/games-live', currentPath),
            _bottomNavItem(Icons.settings, 'Config', '/admin/config', currentPath),
            _bottomNavItem(Icons.more_horiz, 'Plus', '/admin/security', currentPath),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, String path, String currentPath) {
    final isActive = currentPath == path;
    return GestureDetector(
      onTap: () => context.go(path),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? NeonColors.primary : NeonColors.textMuted, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? NeonColors.primary : NeonColors.textMuted,
                fontSize: 10,
              ),
            ),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 2,
                decoration: BoxDecoration(
                  color: NeonColors.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMobileDrawer() {
    final currentPath = GoRouterState.of(context).uri.path;

    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Navigation Admin',
                style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _navItem(Icons.dashboard_outlined, 'Dashboard', '/admin', currentPath),
              _navItem(Icons.bar_chart, 'Métriques', '/admin/metrics', currentPath),
              _navItem(Icons.people, 'Utilisateurs', '/admin/users', currentPath),
              _navItem(Icons.videogame_asset, 'Parties Live', '/admin/games-live', currentPath),
              const Divider(color: NeonColors.border),
              _navItem(Icons.monetization_on, 'Revenue Analytics', '/admin/analytics/revenue', currentPath),
              _navItem(Icons.people_outline, 'Player Analytics', '/admin/analytics/players', currentPath),
              _navItem(Icons.sports_esports, 'Game Analytics', '/admin/analytics/games', currentPath),
              _navItem(Icons.swap_horiz, 'Flux Monétaire', '/admin/analytics/monetary-flow', currentPath),
              _navItem(Icons.account_tree, 'Player Wealth', '/admin/analytics/wealth', currentPath),
              const Divider(color: NeonColors.border),
              _navItem(Icons.tune, 'Game Config', '/admin/game-config', currentPath),
              _navItem(Icons.settings_suggest, 'Plateforme', '/admin/platform-config', currentPath),
              _navItem(Icons.emoji_events, 'Progression', '/admin/player-progression', currentPath),
              _navItem(Icons.card_giftcard, 'Bonus & Promos', '/admin/bonuses', currentPath),
              _navItem(Icons.assessment, 'Rapports', '/admin/reports', currentPath),
              const Divider(color: NeonColors.border),
              _navItem(Icons.settings, 'Configuration', '/admin/config', currentPath),
              _navItem(Icons.monitor_heart, 'Monitoring', '/admin/monitoring', currentPath),
              _navItem(Icons.security, 'Sécurité', '/admin/security', currentPath),
              _navItem(Icons.shield, 'Jeu Responsable', '/admin/responsible-gaming', currentPath),
              _navItem(Icons.people_alt, 'CRM', '/admin/crm', currentPath),
              _navItem(Icons.account_balance, 'Réconciliation', '/admin/reconciliation', currentPath),
              _navItem(Icons.tune, 'Settings', '/admin/settings', currentPath),
              _navItem(Icons.notifications_outlined, 'Notifications', '/admin/notifications', currentPath),
              _navItem(Icons.history, 'Audit', '/admin/audit', currentPath),
              _navItem(Icons.notifications_active, 'Alertes', '/admin/alerts', currentPath),
            ],
          ),
        ),
      ),
    );
  }
}
