import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wiwiga/data/models/game_model.dart';
import 'package:wiwiga/data/models/game_room_model.dart';
import 'package:wiwiga/data/models/game_stats_models.dart';
import 'package:wiwiga/data/providers/game_stats_providers.dart';
import 'package:wiwiga/presentation/screens/games/game_detail_screen.dart';

GameModel _game() {
  return const GameModel(
    id: 'dice',
    name: 'Jeu de Dés',
    description: 'Affrontez un adversaire aux dés.',
    type: 'dice',
    minBet: 100,
    maxBet: 100000,
    houseEdge: 0.05,
    isActive: true,
    maxPlayers: 2,
    playersOnline: 8,
    tips: [GameTip(title: 'Commencez petit', body: 'Misez le minimum.')],
  );
}

List<Override> _overrides() {
  return [
    gameDetailProvider.overrideWith((ref, gameType) => Future.value(_game())),
    gameStatsProvider.overrideWith(
      (ref, gameType) => Future.value(const GameGlobalStats(
        playersOnline: 8,
        matchesToday: 42,
        totalDistributedToday: 250000,
        biggestWinToday: 90000,
        totalPlayers: 120,
      ),),
    ),
    myGameStatsProvider.overrideWith(
      (ref, gameType) => Future.value(const MyGameStats(
        matchesPlayed: 10,
        wins: 6,
        losses: 4,
        totalWagered: 100000,
        totalWonNet: 25000,
        biggestWin: 15000,
        currentStreak: 2,
        bestStreak: 4,
        winRate: 60,
      ),),
    ),
    gameActivityProvider.overrideWith(
      (ref, gameType) => Future.value(<GameActivityEvent>[]),
    ),
    waitingRoomsProvider.overrideWith(
      (ref, gameType) => Future.value(<GameRoomModel>[]),
    ),
    gameLeaderboardProvider.overrideWith(
      (ref, params) => Future.value(const GameLeaderboard(
        metric: 'wins',
        period: 'all',
        entries: [],
      ),),
    ),
    gameRulesProvider.overrideWith(
      (ref, gameType) => Future.value(const [
        GameRuleInfo(
          ruleType: 'normal',
          name: 'Normal',
          description: 'La plus haute somme gagne le set.',
          config: {'default_sets': 3},
        ),
      ]),
    ),
    gameTipsProvider.overrideWith(
      (ref, gameType) => Future.value(const [
        GameTip(title: 'Commencez petit', body: 'Misez le minimum.'),
      ]),
    ),
  ];
}

Widget _wrap() {
  return ProviderScope(
    overrides: _overrides(),
    child: const MaterialApp(
      home: GameDetailScreen(gameType: 'dice'),
    ),
  );
}

void main() {
  group('GameDetailScreen', () {
    testWidgets('affiche le héro et les 4 onglets', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Jeu de Dés'), findsOneWidget);
      expect(find.text('Aperçu'), findsOneWidget);
      expect(find.text('Classement'), findsOneWidget);
      expect(find.text('Règles'), findsOneWidget);
      expect(find.text('Astuces'), findsOneWidget);
    });

    testWidgets('affiche le CTA sticky JOUER + Partie rapide', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('JOUER'), findsOneWidget);
      expect(find.text('Partie rapide'), findsOneWidget);
    });

    testWidgets('onglet Aperçu : stats globales et mes statistiques',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();

      expect(find.text('Joueurs en ligne'), findsOneWidget);
      expect(find.text('Parties du jour'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Mes statistiques'), findsOneWidget);
    });

    testWidgets('onglet Classement : chips métriques et périodes',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Classement'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Victoires'), findsOneWidget);
      expect(find.text('Gains totaux'), findsOneWidget);
      expect(find.text('Plus gros gain'), findsOneWidget);
      expect(find.text('Jour'), findsOneWidget);
      expect(find.text('Semaine'), findsOneWidget);
      expect(find.text('Mois'), findsOneWidget);
      expect(find.text('Toujours'), findsOneWidget);
    });

    testWidgets('onglet Règles : affiche la règle Normal', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Règles'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Normal'), findsWidgets);
      expect(
        find.text('La plus haute somme gagne le set.'),
        findsOneWidget,
      );
    });

    testWidgets('onglet Astuces : affiche les tips du backend',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Astuces'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Commencez petit'), findsOneWidget);
      expect(find.text('Misez le minimum.'), findsOneWidget);
    });

    testWidgets('ne déborde pas en largeur mobile (397px)', (tester) async {
      tester.view.physicalSize = const Size(397, 622);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap());
      await tester.pump();
      await tester.pump();

      // Un overflow RenderFlex ferait échouer le test avec le rapport complet.
      expect(find.text('JOUER'), findsOneWidget);
      expect(find.text('Partie rapide'), findsOneWidget);
    });
  });
}
