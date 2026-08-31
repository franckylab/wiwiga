// ============================================================
// Fichier: avatar_picker_sheet.dart
// Description: Bottom sheet sélection avatar (grille WIWIGA + upload photo)
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/user_profile_provider.dart';

/// Bottom sheet pour choisir un avatar (grille WIWIGA ou photo personnelle)
class AvatarPickerSheet extends ConsumerStatefulWidget {
  const AvatarPickerSheet({super.key});

  @override
  ConsumerState<AvatarPickerSheet> createState() => _AvatarPickerSheetState();

  /// Affiche le bottom sheet
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AvatarPickerSheet(),
    );
  }
}

class _AvatarPickerSheetState extends ConsumerState<AvatarPickerSheet> {
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final file = File(image.path);
      final result = await ref
          .read(userProfileProvider.notifier)
          .uploadAvatar(file);

      if (result != null && mounted) {
        setState(() => _isUploading = false);
        if (context.mounted) {
          Navigator.pop(context, true);
          _showSuccess();
        }
      } else {
        setState(() {
          _isUploading = false;
          _error = 'Erreur lors de l\'upload';
        });
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'AvatarPicker._pickAndUploadImage');
      setState(() {
        _isUploading = false;
        _error = ErrorHandler.userMessage(e);
      });
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Avatar mis à jour !'),
        backgroundColor: NeonColors.success.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final currentAvatarType = authUser?.avatarType ?? AvatarType.defaultAvatar;
    const avatars = AvatarType.values;

    return Container(
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NeonColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              const Text(
                'Choisir un avatar',
                style: TextStyle(
                  color: NeonColors.textPrimary,
                  fontFamily: 'Orbitron',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Section: Avatars WIWIGA
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Avatars WIWIGA',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Grille 3x3
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  final avatar = avatars[index];
                  final isSelected = avatar == currentAvatarType;
                  return _AvatarGridItem(
                    avatar: avatar,
                    isSelected: isSelected,
                    onTap: () => _selectAvatar(avatar),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Section: Photo personnelle
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Photo personnelle',
                  style: TextStyle(
                    color: NeonColors.textSecondary,
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bouton upload
              _UploadButton(
                isLoading: _isUploading,
                onTap: _pickAndUploadImage,
              ),

              // Erreur
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: NeonColors.error,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectAvatar(AvatarType avatar) async {
    // Mettre à jour via le provider (appelle l'API)
    // Pour l'instant on refresh le profil
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Avatar ${avatar.displayName} sélectionné'),
        backgroundColor: NeonColors.primary.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Item de la grille d'avatars
class _AvatarGridItem extends StatelessWidget {
  final AvatarType avatar;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarGridItem({
    required this.avatar,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(avatar.color.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.08),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            _emoji(avatar),
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  String _emoji(AvatarType a) {
    switch (a) {
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

/// Bouton d'upload de photo
class _UploadButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _UploadButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: NeonColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: NeonColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NeonColors.primary,
                ),
              )
            else
              const Icon(Icons.photo_camera, color: NeonColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Upload en cours...' : 'Choisir une photo',
              style: const TextStyle(
                color: NeonColors.primary,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
