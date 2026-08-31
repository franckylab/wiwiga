// ============================================================
// Fichier: profile_edit_sheet.dart
// Description: Bottom sheet édition username avec validation
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../widgets/auth/success_animation.dart';

/// Bottom sheet pour modifier le username
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();

  /// Affiche le bottom sheet
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileEditSheet(),
    );
  }
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSaving = false;
  String? _error;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final currentUsername = ref.read(authProvider).user?.username ?? '';
    _controller.text = currentUsername;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: currentUsername.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Valide le username en temps réel
  void _validateInput(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _validationMessage = 'Le nom d\'utilisateur est requis';
        _error = null;
      });
      return;
    }

    if (trimmed.length < 3) {
      setState(() {
        _validationMessage = 'Minimum 3 caractères';
        _error = null;
      });
      return;
    }

    if (trimmed.length > 30) {
      setState(() {
        _validationMessage = 'Maximum 30 caractères';
        _error = null;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      setState(() {
        _validationMessage =
            'Lettres, chiffres et underscore uniquement';
        _error = null;
      });
      return;
    }

    setState(() {
      _validationMessage = null;
      _error = null;
    });
  }

  bool get _isValid {
    final trimmed = _controller.text.trim();
    return trimmed.length >= 3 &&
        trimmed.length <= 30 &&
        RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed) &&
        _validationMessage == null;
  }

  Future<void> _save() async {
    if (!_isValid) return;

    final newUsername = _controller.text.trim();
    final currentUsername = ref.read(authProvider).user?.username ?? '';

    if (newUsername == currentUsername) {
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final success = await ref
          .read(userProfileProvider.notifier)
          .updateUsername(newUsername);

      if (success && mounted) {
        setState(() => _isSaving = false);
        // Animation succès
        await _showSuccessAnimation();
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _isSaving = false;
          _error = 'Ce nom est déjà pris ou erreur serveur';
        });
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'ProfileEditSheet._save');
      setState(() {
        _isSaving = false;
        _error = ErrorHandler.userMessage(e);
      });
    }
  }

  Future<void> _showSuccessAnimation() async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, __) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SuccessAnimation(
            message: 'Profil mis à jour !',
            duration: Duration(milliseconds: 1000),
          ),
        ),
      ),
      transitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
              'Modifier le profil',
              style: TextStyle(
                color: NeonColors.textPrimary,
                fontFamily: 'Orbitron',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Champ username
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _validateInput,
              autofocus: true,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontFamily: 'Inter',
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Nom d\'utilisateur',
                labelStyle: const TextStyle(
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                ),
                prefixIcon: const Icon(Icons.person_outline,
                    color: NeonColors.primary,),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: NeonColors.textSecondary, size: 18,),
                        onPressed: () {
                          _controller.clear();
                          _validateInput('');
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: NeonColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: NeonColors.primary, width: 2,),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: NeonColors.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: NeonColors.error, width: 2,),
                ),
                filled: true,
                fillColor: NeonColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14,),
              ),
            ),

            // Message de validation
            if (_validationMessage != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationMessage!,
                    style: const TextStyle(
                      color: NeonColors.warning,
                      fontSize: 11,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),

            // Erreur
            if (_error != null)
              Padding(
                padding:
                    const EdgeInsets.only(top: 8, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: NeonColors.error,
                      fontSize: 12,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Boutons
            Row(
              children: [
                // Annuler
                Expanded(
                  child: TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sauvegarder
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValid && !_isSaving ? _save : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: NeonColors.primary,
                      disabledBackgroundColor:
                          NeonColors.border,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sauvegarder',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
