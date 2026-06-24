import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/neon_theme.dart';
import '../../core/theme/typography.dart';
import '../widgets/neon/neon_widgets.dart';

/// Écran d'authentification redesigné avec style néon gaming
class AuthScreenNeon extends StatefulWidget {
  const AuthScreenNeon({Key? key}) : super(key: key);

  @override
  State<AuthScreenNeon> createState() => _AuthScreenNeonState();
}

class _AuthScreenNeonState extends State<AuthScreenNeon>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isOtpSent = false;
  bool _isLoading = false;
  int _countdown = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: NeonAnimations.transition,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Appeler API POST /api/auth/send-otp
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _isOtpSent = true;
      _countdown = 60;
    });

    _startCountdown();
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) return;

    setState(() => _isLoading = true);

    // TODO: Appeler API POST /api/auth/verify-otp
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    // Navigation vers lobby
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connexion réussie !', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: NeonColors.success,
        ),
      );
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
        _startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  
                  // Logo
                  _LogoSection(),
                  
                  const SizedBox(height: 48),
                  
                  // Titre
                  Text(
                    _isOtpSent ? 'VÉRIFICATION' : 'BIENVENUE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: NeonColors.primary,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isOtpSent
                        ? 'Entrez le code reçu par SMS'
                        : 'Connectez-vous pour commencer à jouer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: NeonColors.textSecondary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Formulaire
                  if (!_isOtpSent) ...[
                    _PhoneForm(
                      controller: _phoneController,
                      isLoading: _isLoading,
                      onSubmit: _sendOtp,
                    ),
                  ] else ...[
                    _OtpForm(
                      controller: _otpController,
                      isLoading: _isLoading,
                      countdown: _countdown,
                      onVerify: _verifyOtp,
                      onResend: _sendOtp,
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Footer
                  _FooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: NeonGradients.cta,
          boxShadow: [
            BoxShadow(
              color: NeonColors.primary.withOpacity(NeonGlow.opacityMedium),
              blurRadius: NeonGlow.blurMedium,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(
          Icons.gamepad,
          size: 64,
          color: NeonColors.background,
        ),
      ),
    );
  }
}

class _PhoneForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _PhoneForm({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return NeonInput(
      label: 'Numéro de téléphone',
      hint: '+237 6XX XXX XXX',
      controller: controller,
      keyboardType: TextInputType.phone,
      icon: Icons.phone,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer votre numéro';
        }
        if (value.length < 9) {
          return 'Numéro invalide';
        }
        return null;
      },
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
    
    const SizedBox(height: 32);
    
    NeonButton(
      text: 'RECEVOIR LE CODE',
      onPressed: isLoading ? () {} : onSubmit,
      isLoading: isLoading,
      icon: Icons.send,
      width: double.infinity,
    );
  }
}

class _OtpForm extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final int countdown;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _OtpForm({
    required this.controller,
    required this.isLoading,
    required this.countdown,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NeonInput(
          label: 'Code de vérification',
          hint: '000000',
          controller: controller,
          keyboardType: TextInputType.number,
          icon: Icons.lock_outline,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        
        const SizedBox(height: 24),
        
        NeonButton(
          text: 'VÉRIFIER',
          onPressed: isLoading ? () {} : onVerify,
          isLoading: isLoading,
          icon: Icons.check_circle,
          width: double.infinity,
        ),
        
        const SizedBox(height: 24),
        
        if (countdown > 0)
          Text(
            'Renvoyer le code dans $_countdown s',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontSize: 14,
              fontFamily: 'Inter',
            ),
          )
        else
          TextButton(
            onPressed: onResend,
            child: Text(
              'Renvoyer le code',
              style: TextStyle(
                color: NeonColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(color: NeonColors.border),
        const SizedBox(height: 16),
        Text(
          'En continuant, vous acceptez nos',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 12,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text(
                'Conditions d\'utilisation',
                style: TextStyle(
                  color: NeonColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            Text(
              'et',
              style: TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Politique de confidentialité',
                style: TextStyle(
                  color: NeonColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
