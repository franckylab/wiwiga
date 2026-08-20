import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_button.dart';
import '../../widgets/neon/neon_card.dart';
import '../../providers/config_provider.dart';

/// Type de document légal
enum LegalDocumentType {
  terms,
  privacy,
}

/// Écran d'affichage des documents légaux (CGU, Politique de confidentialité)
class LegalScreen extends ConsumerWidget {
  final LegalDocumentType documentType;

  const LegalScreen({super.key, required this.documentType});

  String get _title => documentType == LegalDocumentType.terms
      ? 'Conditions Générales d\'Utilisation'
      : 'Politique de Confidentialité';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureConfigAsync = ref.watch(featureConfigProvider);
    final featureConfig = featureConfigAsync.value;
    final url = documentType == LegalDocumentType.terms
        ? (featureConfig?.termsUrl ?? 'https://wiwiga.cm/terms')
        : (featureConfig?.privacyUrl ?? 'https://wiwiga.cm/privacy');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
        iconTheme: const IconThemeData(color: NeonColors.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          documentType == LegalDocumentType.terms
                              ? Icons.description
                              : Icons.privacy_tip,
                          color: NeonColors.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _title,
                            style: AppTypography.heading2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dernière mise à jour: 17 Août 2026',
                      style: TextStyle(
                        color: NeonColors.textSecondary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contenu
            if (documentType == LegalDocumentType.terms)
              _buildTermsContent()
            else
              _buildPrivacyContent(),

            const SizedBox(height: 24),

            // Lien vers le site
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Version complète en ligne',
                      style: TextStyle(
                        color: NeonColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      url,
                      style: const TextStyle(
                        color: NeonColors.primary,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bouton de fermeture
            NeonButton(
              text: 'FERMER',
              onPressed: () => Navigator.pop(context),
              variant: NeonButtonVariant.primary,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Acceptation des conditions',
                'En utilisant l\'application WIWIGA, vous acceptez pleinement et sans réserve les présentes conditions générales d\'utilisation. Si vous n\'acceptez pas ces conditions, veuillez ne pas utiliser l\'application.',),
            const SizedBox(height: 16),
            _buildSection('2. Description du service',
                'WIWIGA est une plateforme de jeux de société en ligne, permettant aux utilisateurs de jouer à des jeux de dés et de cartes avec d\'autres joueurs. Le service inclut la gestion de comptes utilisateurs, de jetons virtuels, et de classements.',),
            const SizedBox(height: 16),
            _buildSection('3. Compte utilisateur',
                'Pour utiliser les fonctionnalités complètes de l\'application, vous devez créer un compte. Vous êtes responsable de la confidentialité de vos identifiants et de toutes les activités effectuées via votre compte.',),
            const SizedBox(height: 16),
            _buildSection('4. Jetons virtuels',
                'Les jetons WIWIGA sont une monnaie virtuelle interne à l\'application. Ils n\'ont aucune valeur réelle et ne peuvent être échangés contre de l\'argent réel. Les jetons achetés sont non remboursables sauf dans les cas prévus par la loi.',),
            const SizedBox(height: 16),
            _buildSection('5. Comportement interdit',
                'Sont interdits : la triche, l\'utilisation de bots, le harcèlement d\'autres joueurs, la tentative de piratage, toute activité illégale ou contraire aux bonnes mœurs. Le non-respect de ces règles peut entraîner la suspension ou la bannissement de votre compte.',),
            const SizedBox(height: 16),
            _buildSection('6. Responsabilité',
                'WIWIGA s\'efforce de fournir un service de qualité mais ne garantit pas une disponibilité continue ni l\'absence de bugs. Nous ne sommes pas responsables des pertes de jetons dues à des bugs ou à une utilisation abusive.',),
            const SizedBox(height: 16),
            _buildSection('7. Modification des conditions',
                'Nous nous réservons le droit de modifier ces conditions à tout moment. Les modifications entreront en vigueur dès leur publication dans l\'application. L\'utilisation continue du service après modification constitue votre acceptation des nouvelles conditions.',),
            const SizedBox(height: 16),
            _buildSection('8. Contact',
                'Pour toute question concernant ces conditions, veuillez nous contacter à support@wiwiga.cm',),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('1. Collecte des données',
                'Nous collectons les données suivantes : numéro de téléphone ou email, nom d\'utilisateur, données de jeu (statistiques, historique), et informations sur l\'appareil (modèle, système d\'exploitation).',),
            const SizedBox(height: 16),
            _buildSection('2. Utilisation des données',
                'Vos données sont utilisées pour : fournir le service, gérer votre compte, afficher les classements, améliorer l\'expérience utilisateur, et assurer la sécurité de la plateforme.',),
            const SizedBox(height: 16),
            _buildSection('3. Partage des données',
                'Nous ne partageons pas vos données personnelles avec des tiers, sauf : avec votre consentement, pour respecter une obligation légale, pour protéger nos droits ou la sécurité de la plateforme.',),
            const SizedBox(height: 16),
            _buildSection('4. Sécurité',
                'Nous mettons en œuvre des mesures de sécurité appropriées pour protéger vos données contre tout accès non autorisé, modification, divulgation ou destruction.',),
            const SizedBox(height: 16),
            _buildSection('5. Durée de conservation',
                'Vos données sont conservées pendant la durée de votre compte et jusqu\'à 3 ans après sa suppression pour des raisons légales ou de sécurité.',),
            const SizedBox(height: 16),
            _buildSection('6. Vos droits',
                'Vous disposez des droits suivants : accès à vos données, rectification, suppression, limitation du traitement, portabilité. Pour exercer ces droits, contactez-nous à privacy@wiwiga.cm',),
            const SizedBox(height: 16),
            _buildSection('7. Cookies et traceurs',
                'L\'application utilise des traceurs techniques nécessaires à son fonctionnement (session, authentification). Aucun cookie publicitaire n\'est utilisé sans votre consentement.',),
            const SizedBox(height: 16),
            _buildSection('8. Modification de la politique',
                'Cette politique peut être modifiée à tout moment. La date de dernière mise à jour est indiquée en haut du document.',),
            const SizedBox(height: 16),
            _buildSection('9. Contact',
                'Pour toute question concernant cette politique ou vos données personnelles, contactez-nous à privacy@wiwiga.cm',),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: NeonColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: NeonColors.textSecondary,
            fontSize: 13,
            fontFamily: 'Inter',
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
