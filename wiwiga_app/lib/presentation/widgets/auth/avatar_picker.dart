// ============================================================
// Fichier: avatar_picker.dart
// Description: Widget de sélection d'avatar prédéfini WIWIGA
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import '../../../data/models/user_model.dart';

/// Widget de sélection d'avatar parmi les avatars prédéfinis WIWIGA
class AvatarPicker extends StatelessWidget {
  final AvatarType selectedAvatar;
  final ValueChanged<AvatarType> onAvatarSelected;
  final double avatarSize;

  const AvatarPicker({
    super.key,
    required this.selectedAvatar,
    required this.onAvatarSelected,
    this.avatarSize = 70,
  });

  @override
  Widget build(BuildContext context) {
    final avatars = AvatarType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choisis ton avatar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: avatarSize + 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: avatars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final avatar = avatars[index];
              final isSelected = avatar == selectedAvatar;

              return GestureDetector(
                onTap: () => onAvatarSelected(avatar),
                child: _AvatarItem(
                  avatar: avatar,
                  isSelected: isSelected,
                  size: avatarSize,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final AvatarType avatar;
  final bool isSelected;
  final double size;

  const _AvatarItem({
    required this.avatar,
    required this.isSelected,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(avatar.color.replaceFirst('#', '0xFF')));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(isSelected ? 0.3 : 0.1),
            border: Border.all(
              color: isSelected ? color : color.withOpacity(0.3),
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              _avatarEmoji(avatar),
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          avatar.displayName,
          style: TextStyle(
            color: isSelected ? color : Colors.white54,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _avatarEmoji(AvatarType avatar) {
    switch (avatar) {
      case AvatarType.defaultAvatar:
        return '🎮';
      case AvatarType.wiwiga1:
        return '🎧';
      case AvatarType.wiwiga2:
        return '🕹️';
      case AvatarType.wiwiga3:
        return '🎲';
      case AvatarType.wiwiga4:
        return '👑';
      case AvatarType.wiwiga5:
        return '🤖';
      case AvatarType.wiwiga6:
        return '🐉';
      case AvatarType.wiwiga7:
        return '🔥';
      case AvatarType.wiwiga8:
        return '⭐';
    }
  }
}

/// Avatar display widget (utilisé dans les listes, profils, etc.)
class AvatarDisplay extends StatelessWidget {
  final AvatarType avatarType;
  final String? username;
  final double size;

  const AvatarDisplay({
    super.key,
    required this.avatarType,
    this.username,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(avatarType.color.replaceFirst('#', '0xFF')));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Center(
        child: Text(
          _avatarEmoji(avatarType),
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }

  String _avatarEmoji(AvatarType avatar) {
    switch (avatar) {
      case AvatarType.defaultAvatar:
        return '🎮';
      case AvatarType.wiwiga1:
        return '🎧';
      case AvatarType.wiwiga2:
        return '🕹️';
      case AvatarType.wiwiga3:
        return '🎲';
      case AvatarType.wiwiga4:
        return '👑';
      case AvatarType.wiwiga5:
        return '🤖';
      case AvatarType.wiwiga6:
        return '🐉';
      case AvatarType.wiwiga7:
        return '🔥';
      case AvatarType.wiwiga8:
        return '⭐';
    }
  }
}
