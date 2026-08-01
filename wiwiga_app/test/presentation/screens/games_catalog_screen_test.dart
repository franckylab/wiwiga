import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/data/models/game_model.dart';
import 'package:wiwiga/data/providers/game_stats_providers.dart';
import 'package:wiwiga/presentation/screens/games/games_catalog_screen.dart';

GameModel _game({
  String type = 'dice',
  String name = 'Jeu de Dés',
  bool comingSoon = false,
  int playersOnline = 12,
}) {
  return GameModel(
    id: type,
    name: name,
    description: 'Affrontez un adversaire aux dés.',
    type: type,
    minBet: 100,
    maxBet: 100000,
    houseEdge: 0.05,
    isActive: true,
    maxPlayers: 2,
    comingSoon: comingSoon,
    playersOnline: playersOnline,
  );
}

Widget _wrap(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: GamesCatalogScreen()),
  );
}

void main() {
  group('GamesCatalogScreen', () {
    testWidgets('affiche le header du catalogue', (tester) async {
      await tester.pumpWidget(_wrap([
        gamesCatalogProvider.overrideWith((ref) => Future.value([_game()])),
      ]),);
      await tester.pump();

      expect(find.text('Catalogue des jeux'), findsOneWidget);
      expect(
        find.text('Choisissez votre jeu et défiez la communauté'),
        findsOneWidget,
      );
    });

    testWidgets('affiche la carte d\'un jeu actif avec CTA Découvrir',
        (tester) async {
      await tester.pumpWidget(_wrap([
        gamesCatalogProvider.overrideWith((ref) => Future.value([_game()])),
      ]),);
      await tester.pump();

      expect(find.text('Jeu de Dés'), findsOneWidget);
      expect(find.text('12 en ligne'), findsOneWidget);
      expect(find.text('Découvrir'), findsOneWidget);
      expect(find.textContaining('Mise min.'), findsOneWidget);
    });

    testWidgets('affiche les jeux à venir grisés sans CTA', (tester) async {
      await tester.pumpWidget(_wrap([
        gamesCatalogProvider.overrideWith((ref) => Future.value([
              _game(type: 'ludo', name: 'Ludo', comingSoon: true),
            ]),),
      ]),);
      await tester.pump();

      expect(find.text('Ludo'), findsOneWidget);
      expect(find.text('Bientôt disponible'), findsOneWidget);
      expect(find.text('Découvrir'), findsNothing);
    });

    testWidgets('affiche l\'état vide sans jeux', (tester) async {
      await tester.pumpWidget(_wrap([
        gamesCatalogProvider
            .overrideWith((ref) => Future.value(<GameModel>[])),
      ]),);
      await tester.pump();

      expect(
        find.text('Aucun jeu disponible pour le moment'),
        findsOneWidget,
      );
    });

    testWidgets('affiche l\'état d\'erreur avec bouton Réessayer',
        (tester) async {
      await tester.pumpWidget(_wrap([
        gamesCatalogProvider
            .overrideWith((ref) => Future<List<GameModel>>.error('boom')),
      ]),);
      await tester.pump();

      expect(find.text('Impossible de charger les jeux'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
