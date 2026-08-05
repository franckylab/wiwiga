// ============================================================
// Fichier: auth_screen_v2.dart
// Description: Écran d'authentification multi-méthodes
//              Login (password) + Inscription (OTP + profil)
//              Avec animations de succès
// Auteur: WIWIGA Team
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/auth/avatar_picker.dart';
import '../../widgets/auth/success_animation.dart';

/// Écran d'authentification multi-méthodes
///
/// Flux:
/// 1. Accueil: Choix "Se connecter" ou "Créer un compte"
/// 2a. Login: phone/email + mot de passe → animation succès → home
/// 2b. Inscription: phone/email → OTP → profil (username + avatar) → animation succès → home
class AuthScreenV2 extends ConsumerStatefulWidget {
  const AuthScreenV2({super.key});

  @override
  ConsumerState<AuthScreenV2> createState() => _AuthScreenV2State();
}

enum _AuthFlow { welcome, login, registerIdentifier, otp, profile, loginSuccess, registerSuccess, logoutSuccess }
enum _AuthMethod { phone, email }

class _AuthScreenV2State extends ConsumerState<AuthScreenV2>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _AuthFlow _currentFlow = _AuthFlow.welcome;
  _AuthMethod _selectedMethod = _AuthMethod.phone;
  AvatarType _selectedAvatar = AvatarType.defaultAvatar;
  String _identifier = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  int _countdown = 0;
  Timer? _countdownTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _error = null;
      _identifierController.clear();
      _passwordController.clear();
      _otpController.clear();
      _usernameController.clear();
    });
  }

  void _startCountdown() {
    _countdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  // ========================================
  // Actions
  // ========================================

  Future<void> _loginWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    try {
      final authNotifier = ref.read(authProvider.notifier);

      if (_selectedMethod == _AuthMethod.phone) {
        await authNotifier.loginWithPassword(phone: _identifier, password: password);
      } else {
        await authNotifier.loginWithPassword(email: _identifier, password: password);
      }

      final newState = ref.read(authProvider);
      
      if (newState.error == 'otp_required') {
        // OTP requis: aller à l'étape OTP
        setState(() {
          _currentFlow = _AuthFlow.otp;
          _isLoading = false;
          _error = null;
        });
        _startCountdown();
      } else if (newState.isAuthenticated) {
        // Animation succès puis navigation
        setState(() {
          _currentFlow = _AuthFlow.loginSuccess;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = newState.error ?? 'Erreur de connexion';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Identifiants incorrects. Vérifiez votre numéro/email et mot de passe.';
      });
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _identifier = _identifierController.text.trim();

    try {
      final authNotifier = ref.read(authProvider.notifier);

      if (_selectedMethod == _AuthMethod.phone) {
        await authNotifier.sendOtp(_identifier);
      } else {
        await authNotifier.sendOtpByEmail(_identifier);
      }

      setState(() {
        _currentFlow = _AuthFlow.otp;
        _isLoading = false;
      });
      _startCountdown();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
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
      final authNotifier = ref.read(authProvider.notifier);

      if (_selectedMethod == _AuthMethod.phone) {
        await authNotifier.verifyOtp(phoneNumber: _identifier, otpCode: otp);
      } else {
        await authNotifier.verifyOtpByEmail(email: _identifier, otpCode: otp);
      }

      final newState = ref.read(authProvider);
      if (newState.isAuthenticated) {
        final user = newState.user;
        if (user != null && (user.username.isEmpty || user.username.startsWith('player_'))) {
          setState(() {
            _currentFlow = _AuthFlow.profile;
            _isLoading = false;
          });
        } else {
          // Animation succès inscription
          setState(() {
            _currentFlow = _AuthFlow.registerSuccess;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Code OTP invalide. Réessayez.';
      });
    }
  }

  Future<void> _completeProfile() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Le pseudonyme doit contenir au moins 3 caractères');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authNotifier = ref.read(authProvider.notifier);
      await authNotifier.completeProfile(
        username: username,
        avatarType: _selectedAvatar.value,
      );
      // Animation succès inscription
      setState(() {
        _currentFlow = _AuthFlow.registerSuccess;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _navigateToHome() {
    final authState = ref.read(authProvider);
    final redirectTo = authState.redirectTo ?? '/home';
    context.go(redirectTo);
  }

  // ========================================
  // Build
  // ========================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentFlow(authState),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentFlow(AuthState authState) {
    switch (_currentFlow) {
      case _AuthFlow.welcome:
        return _buildWelcome();
      case _AuthFlow.login:
        return _buildLogin();
      case _AuthFlow.registerIdentifier:
        return _buildRegisterIdentifier();
      case _AuthFlow.otp:
        return _buildOtpStep();
      case _AuthFlow.profile:
        return _buildProfileStep();
      case _AuthFlow.loginSuccess:
        return _buildLoginSuccess();
      case _AuthFlow.registerSuccess:
        return _buildRegisterSuccess();
      case _AuthFlow.logoutSuccess:
        return _buildLogoutSuccess();
    }
  }

  // ========================================
  // Welcome
  // ========================================
  Widget _buildWelcome() {
    return Column(
      key: const ValueKey('welcome'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        // Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00FF88).withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.casino, size: 64, color: Color(0xFF00FF88)),
        ),
        const SizedBox(height: 20),
        Text(
          'WIWIGA',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00FF88),
            shadows: [
              Shadow(color: const Color(0xFF00FF88).withValues(alpha: 0.4), blurRadius: 24),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Joue. Gagne. Partage.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
        ),
        const SizedBox(height: 48),

        // Bouton Se connecter
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              _resetState();
              setState(() => _currentFlow = _AuthFlow.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton Créer un compte
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: () {
              _resetState();
              setState(() => _currentFlow = _AuthFlow.registerIdentifier);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00FF88), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Créer un compte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00FF88))),
          ),
        ),
      ],
    );
  }

  // ========================================
  // Login (password)
  // ========================================
  Widget _buildLogin() {
    return Column(
      key: const ValueKey('login'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.lock_open, size: 48, color: Color(0xFF00FF88)),
        const SizedBox(height: 12),
        const Text(
          'Connexion',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 24),

        // Méthode phone/email
        _buildMethodSelector(),
        const SizedBox(height: 20),

        // Formulaire
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Identifiant
              TextFormField(
                controller: _identifierController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: _selectedMethod == _AuthMethod.phone
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: _selectedMethod == _AuthMethod.phone ? '+237 6XX XXX XXX' : 'votre@email.com',
                  icon: _selectedMethod == _AuthMethod.phone ? Icons.phone : Icons.email,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Ce champ est requis';
                  if (_selectedMethod == _AuthMethod.phone && !value.contains(RegExp(r'[0-9]'))) return 'Numéro invalide';
                  if (_selectedMethod == _AuthMethod.email && !value.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mot de passe
              TextFormField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                obscureText: _obscurePassword,
                decoration: _inputDecoration(
                  hint: 'Mot de passe',
                  icon: Icons.lock,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Mot de passe requis';
                  if (value.length < 8) return '8 caractères minimum';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Erreur
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
          ),

        // Bouton connexion
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginWithPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),

        // Pas de compte ?
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pas de compte ?', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            TextButton(
              onPressed: () {
                _resetState();
                setState(() => _currentFlow = _AuthFlow.registerIdentifier);
              },
              child: const Text('S\'inscrire', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        // Retour
        TextButton(
          onPressed: () {
            _resetState();
            setState(() => _currentFlow = _AuthFlow.welcome);
          },
          child: const Text('Retour', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // ========================================
  // Register - Saisie identifiant
  // ========================================
  Widget _buildRegisterIdentifier() {
    return Column(
      key: const ValueKey('register_id'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.person_add, size: 48, color: Color(0xFF00FF88)),
        const SizedBox(height: 12),
        const Text(
          'Créer un compte',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Inscris-toi avec ton téléphone ou email',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildMethodSelector(),
        const SizedBox(height: 20),

        Form(
          key: _formKey,
          child: TextFormField(
            controller: _identifierController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            keyboardType: _selectedMethod == _AuthMethod.phone
                ? TextInputType.phone
                : TextInputType.emailAddress,
            decoration: _inputDecoration(
              hint: _selectedMethod == _AuthMethod.phone ? '+237 6XX XXX XXX' : 'votre@email.com',
              icon: _selectedMethod == _AuthMethod.phone ? Icons.phone : Icons.email,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Ce champ est requis';
              if (_selectedMethod == _AuthMethod.phone && !value.contains(RegExp(r'[0-9]'))) return 'Numéro invalide';
              if (_selectedMethod == _AuthMethod.email && !value.contains('@')) return 'Email invalide';
              return null;
            },
          ),
        ),
        const SizedBox(height: 16),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
          ),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continuer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Déjà un compte ?', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            TextButton(
              onPressed: () {
                _resetState();
                setState(() => _currentFlow = _AuthFlow.login);
              },
              child: const Text('Se connecter', style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        TextButton(
          onPressed: () {
            _resetState();
            setState(() => _currentFlow = _AuthFlow.welcome);
          },
          child: const Text('Retour', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  // ========================================
  // OTP Step
  // ========================================
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.security, size: 48, color: Color(0xFF00FF88)),
        const SizedBox(height: 16),
        const Text(
          'Vérification',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'Code envoyé à $_identifier',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 32),

        TextFormField(
          controller: _otpController,
          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 24, letterSpacing: 8),
            counterText: '',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2)),
          ),
        ),
        const SizedBox(height: 16),

        if (_countdown > 0)
          Text('Renvoyer dans ${_countdown}s', style: TextStyle(color: Colors.white.withValues(alpha: 0.4)))
        else
          TextButton(onPressed: _sendOtp, child: const Text('Renvoyer le code', style: TextStyle(color: Color(0xFF00FF88)))),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
          ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Vérifier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),

        TextButton(
          onPressed: () => setState(() {
            _currentFlow = _AuthFlow.registerIdentifier;
            _error = null;
          }),
          child: const Text('Retour', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  // ========================================
  // Profile Step
  // ========================================
  Widget _buildProfileStep() {
    return Column(
      key: const ValueKey('profile'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, size: 48, color: Color(0xFF00FF88)),
        const SizedBox(height: 16),
        const Text(
          'Complète ton profil',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 32),

        TextFormField(
          controller: _usernameController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: _inputDecoration(hint: 'Ton pseudonyme', icon: Icons.alternate_email),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]'))],
          maxLength: 30,
        ),
        const SizedBox(height: 24),

        AvatarPicker(
          selectedAvatar: _selectedAvatar,
          onAvatarSelected: (avatar) => setState(() => _selectedAvatar = avatar),
        ),
        const SizedBox(height: 24),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
          ),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _completeProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: const Color(0xFF0A0A1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('C\'est parti !', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ========================================
  // Success Animations
  // ========================================
  
  Widget _buildLoginSuccess() {
    return Column(
      key: const ValueKey('login_success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SuccessAnimation(
          message: 'Connexion réussie !',
          subtitle: 'Bienvenue sur WIWIGA',
          onComplete: () {
            Future.delayed(const Duration(milliseconds: 500), _navigateToHome);
          },
        ),
      ],
    );
  }

  Widget _buildRegisterSuccess() {
    return Column(
      key: const ValueKey('register_success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SuccessAnimation(
          message: 'Inscription réussie !',
          subtitle: 'Ton compte WIWIGA est prêt',
          color: const Color(0xFF00FF88),
          onComplete: () {
            Future.delayed(const Duration(milliseconds: 500), _navigateToHome);
          },
        ),
      ],
    );
  }

  Widget _buildLogoutSuccess() {
    return Column(
      key: const ValueKey('logout_success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SuccessAnimation(
          message: 'Déconnecté',
          subtitle: 'À bientôt sur WIWIGA !',
          color: const Color(0xFF00FF88),
          onComplete: () {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                context.go('/auth');
              }
            });
          },
        ),
      ],
    );
  }

  // ========================================
  // Shared widgets
  // ========================================

  Widget _buildMethodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _MethodTab(
            icon: Icons.phone,
            label: 'Téléphone',
            isSelected: _selectedMethod == _AuthMethod.phone,
            onTap: () => setState(() => _selectedMethod = _AuthMethod.phone),
          ),
          _MethodTab(
            icon: Icons.email,
            label: 'Email',
            isSelected: _selectedMethod == _AuthMethod.email,
            onTap: () => setState(() => _selectedMethod = _AuthMethod.email),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      prefixIcon: Icon(icon, color: const Color(0xFF00FF88)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 2)),
    );
  }
}

class _MethodTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00FF88).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: const Color(0xFF00FF88), width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00FF88) : Colors.white54, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00FF88) : Colors.white54,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
