// ============================================================
// Fichier: auth_gate.dart
// Description: Widget AuthGate — contrôle d'accès aux actions protégées
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';

/// Type de mur d'authentification
enum AuthGateType {
  /// Modal bottom sheet — reste dans le contexte
  softWall,
  
  /// Redirection vers /auth — perd le contexte
  hardWall,
}

/// Widget qui enveloppe une action protégée par authentification.
/// 
/// Si l'utilisateur est authentifié, l'action s'exécute normalement.
/// Si l'utilisateur est guest, affiche un AuthGate (modal ou redirect).
/// 
/// Usage:
/// ```dart
/// AuthGate(
///   type: AuthGateType.softWall,
///   action: () => context.go('/games/dice/lobby'),
///   child: NeonButton(text: 'JOUER', onPressed: ...),
/// )
/// ```
class AuthGate extends ConsumerWidget {
  /// Type de mur (soft wall = modal, hard wall = redirect)
  final AuthGateType type;
  
  /// Action à exécuter si authentifié
  final VoidCallback action;
  
  /// Widget enfant (bouton, carte, etc.)
  final Widget child;
  
  /// Message personnalisé pour le modal
  final String? message;
  
  /// Titre personnalisé pour le modal
  final String? title;
  
  const AuthGate({
    super.key,
    this.type = AuthGateType.softWall,
    required this.action,
    required this.child,
    this.message,
    this.title,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    return GestureDetector(
      onTap: () {
        if (authState.isAuthenticated) {
          // Utilisateur authentifié, exécuter l'action
          action();
        } else {
          // Utilisateur guest, montrer le gate
          _showGate(context, ref);
        }
      },
      child: child,
    );
  }
  
  void _showGate(BuildContext context, WidgetRef ref) {
    switch (type) {
      case AuthGateType.softWall:
        _showSoftWall(context, ref);
        break;
      case AuthGateType.hardWall:
        _showHardWall(context, ref);
        break;
    }
  }
  
  /// Soft Wall — Modal bottom sheet d'authentification in-context
  void _showSoftWall(BuildContext context, WidgetRef ref) {
    // Sauvegarder l'intent de redirection
    final currentRoute = GoRouterState.of(context).uri.toString();
    ref.read(authProvider.notifier).setRedirectTo(currentRoute);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AuthBottomSheet(
        title: title ?? 'Connexion requise',
        message: message ?? 'Connectez-vous pour accéder à cette fonctionnalité.',
        onAuthSuccess: () {
          Navigator.of(context).pop();
          // Exécuter l'action après authentification réussie
          action();
        },
      ),
    );
  }
  
  /// Hard Wall — Redirection vers /auth
  void _showHardWall(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    ref.read(authProvider.notifier).setRedirectTo(currentRoute);
    context.go('/auth');
  }
}

/// Widget utilitaire pour les boutons d'action protégés
/// 
/// Variante de AuthGate qui affiche un bouton avec état désactivé en mode guest.
class AuthProtectedButton extends ConsumerWidget {
  final String text;
  final VoidCallback action;
  final AuthGateType gateType;
  final bool disabled;
  final String? gateMessage;
  
  const AuthProtectedButton({
    super.key,
    required this.text,
    required this.action,
    this.gateType = AuthGateType.softWall,
    this.disabled = false,
    this.gateMessage,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthGate(
      type: gateType,
      action: action,
      message: gateMessage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: disabled ? null : NeonGradients.cta,
          color: disabled ? NeonColors.card : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: NeonColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: disabled ? NeonColors.textMuted : NeonColors.background,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Orbitron',
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet d'authentification
class _AuthBottomSheet extends ConsumerStatefulWidget {
  final String title;
  final String message;
  final VoidCallback onAuthSuccess;
  
  const _AuthBottomSheet({
    required this.title,
    required this.message,
    required this.onAuthSuccess,
  });
  
  @override
  ConsumerState<_AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<_AuthBottomSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _error;
  
  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
  
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      setState(() => _error = 'Numéro de téléphone invalide');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      setState(() {
        _isLoading = false;
        _isOtpSent = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
  
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Le code OTP doit contenir 6 chiffres');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      await ref.read(authProvider.notifier).verifyOtp(
        phoneNumber: _phoneController.text.trim(),
        otpCode: otp,
      );
      
      final authState = ref.read(authProvider);
      if (authState.isAuthenticated) {
        widget.onAuthSuccess();
      } else {
        setState(() {
          _isLoading = false;
          _error = authState.error ?? 'Erreur d\'authentification';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
          const SizedBox(height: 24),
          
          // Icône
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: NeonGradients.cta,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: NeonColors.background,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          
          // Titre
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: NeonColors.primary,
              fontFamily: 'Orbitron',
            ),
          ),
          const SizedBox(height: 8),
          
          // Message
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 24),
          
          // Erreur
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeonColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: NeonColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: NeonColors.error,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Formulaire
          if (!_isOtpSent) ...[
            // Champ téléphone
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: NeonColors.textPrimary, fontFamily: 'Inter'),
              decoration: InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: '+237 6XX XXX XXX',
                prefixIcon: const Icon(Icons.phone, color: NeonColors.primary),
                labelStyle: const TextStyle(color: NeonColors.textSecondary),
                hintStyle: const TextStyle(color: NeonColors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NeonColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NeonColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeonColors.primary,
                  foregroundColor: NeonColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NeonColors.background,
                        ),
                      )
                    : const Text(
                        'RECEVOIR LE CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ] else ...[
            // Champ OTP
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NeonColors.textPrimary,
                fontFamily: 'Orbitron',
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                labelText: 'Code OTP',
                counterText: '',
                labelStyle: const TextStyle(color: NeonColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NeonColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: NeonColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Bouton vérifier
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NeonColors.success,
                  foregroundColor: NeonColors.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NeonColors.background,
                        ),
                      )
                    : const Text(
                        'VÉRIFIER',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Orbitron',
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Lien vers page auth complète
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/auth');
            },
            child: const Text(
              'Ouvrir la page de connexion',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
