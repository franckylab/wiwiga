import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_widgets.dart';

/// Écran Profile redesigné avec style néon gaming
class ProfileScreenNeon extends StatelessWidget {
  const ProfileScreenNeon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PROFIL',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: NeonColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            _ProfileHeader(),
            
            // Stats
            _ProfileStats(),
            
            // Settings Sections
            _SettingsSections(),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NeonGradients.card,
      ),
      child: Column(
        children: [
          // Avatar avec rang
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NeonColors.primary,
                    width: NeonGlow.borderWidthThick,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: NeonColors.primary.withOpacity(NeonGlow.opacityMedium),
                      blurRadius: NeonGlow.blurMedium,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: NeonColors.surface,
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: NeonColors.primary,
                  ),
                ),
              ),
              RankBadge(
                rank: 'Or',
                size: 36,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Nom
          Text(
            'Franck CHENDJOU',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeonColors.textPrimary,
              fontFamily: 'Orbitron',
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Phone
          Text(
            '+237 699 999 999',
            style: TextStyle(
              fontSize: 16,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Badge KYC
          GlowBadge(
            text: 'KYC Vérifié',
            color: NeonColors.success,
          ),
        ],
      ),
    );
  }
}

class _ProfileStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: NeonCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STATISTIQUES',
                style: AppTypography.heading3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.games,
                      label: 'Jeux joués',
                      value: '156',
                      color: NeonColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events,
                      label: 'Victoires',
                      value: '97',
                      color: NeonColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      label: 'Win Rate',
                      value: '62%',
                      color: NeonColors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department,
                      label: 'Meilleure série',
                      value: '12',
                      color: NeonColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.attach_money,
                      label: 'Total gagné',
                      value: '2.5M',
                      color: NeonColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.star,
                      label: 'Points XP',
                      value: '8,450',
                      color: NeonColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Orbitron',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: NeonColors.textSecondary,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _SettingsSections extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paramètres du compte
          Text(
            'PARAMÈTRES DU COMPTE',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Modifier le profil',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Changer le mot de passe',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.phone_android,
                title: 'Changer le numéro',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.security,
                title: 'Vérification KYC',
                trailing: GlowBadge(
                  text: 'Vérifié',
                  color: NeonColors.success,
                  fontSize: 10,
                ),
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Préférences
          Text(
            'PRÉFÉRENCES',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: NeonColors.primary,
                ),
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Sons',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: NeonColors.primary,
                ),
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.animation,
                title: 'Animations',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: NeonColors.primary,
                ),
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Jeu responsable
          Text(
            'JEU RESPONSABLE',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Limites de dépôt',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.schedule,
                title: 'Limites de temps',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.block,
                title: 'Auto-exclusion',
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Support
          Text(
            'SUPPORT',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Centre d\'aide',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.chat_outlined,
                title: 'Contacter le support',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Conditions d\'utilisation',
                onTap: () {},
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Politique de confidentialité',
                onTap: () {},
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Déconnexion
          NeonButton(
            text: 'DÉCONNEXION',
            onPressed: () {},
            variant: NeonButtonVariant.danger,
            icon: Icons.logout,
            width: double.infinity,
          ),
          
          const SizedBox(height: 24),
          
          // Version
          Center(
            child: Text(
              'WIWIGA v1.0.0',
              style: TextStyle(
                color: NeonColors.textSecondary.withOpacity(0.5),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: NeonColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: NeonColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
            ] else ...[
              Icon(
                Icons.chevron_right,
                color: NeonColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: NeonColors.border, height: 1),
    );
  }
}
