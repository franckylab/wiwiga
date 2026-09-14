# ==================================
# WIWIGA - Tests GameMatch
# ==================================
defmodule GameHub.GameMatchTest do
  use ExUnit.Case, async: false

  alias GameHub.GameMatch

  setup do
    # Le GenServer est déjà supervisé par l'application en env test :
    # démarrage idempotent (évite {:error, {:already_started, _}}).
    case GameMatch.start_link() do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end
    :ok
  end

  describe "create_match/1" do
    test "crée un match avec config par défaut" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: :free,
        creator_id: "player_1"
      }

      assert {:ok, match} = GameMatch.create_match(config)
      assert match.game_type == "dice"
      assert match.rule_type == "normal"
      assert match.status == :waiting_players
      assert match.sets_count == 3
      assert match.dice_count == 2
    end

    test "crée un match avec config custom (Partie avec mise)" do
      config = %{
        game_type: "dice",
        rule_type: "cible",
        mode: :staked,
        sets_count: 5,
        dice_count: 3,
        bet_amount: 1000,
        max_players: 4,
        creator_id: "player_1"
      }

      assert {:ok, match} = GameMatch.create_match(config)
      assert match.mode == :staked
      assert match.sets_count == 5
      assert match.dice_count == 3
      assert match.bet_amount == 1000
      assert match.max_players == 4
    end

    test "mode betting supprimé — erreur" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: :betting,
        bet_amount: 500,
        creator_id: "player_1"
      }

      assert {:error, :invalid_mode} = GameMatch.create_match(config)
    end

    test "mode string betting supprimé — erreur" do
      config = %{
        game_type: "dice",
        rule_type: "normal",
        mode: "betting",
        bet_amount: 500,
        creator_id: "player_1"
      }

      assert {:error, :invalid_mode} = GameMatch.create_match(config)
    end
  end

  describe "add_player/3" do
    test "ajoute un joueur au match" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "Joueur 1")
      assert {:ok, updated} = GameMatch.add_player(match.match_id, "p2", "Joueur 2")
      assert length(updated.players) == 2
    end

    test "refuse si match plein" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", max_players: 2, creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1")
      GameMatch.add_player(match.match_id, "p2")
      assert {:error, :match_full} = GameMatch.add_player(match.match_id, "p3")
    end

    test "refuse doublon" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1")
      assert {:error, :already_joined} = GameMatch.add_player(match.match_id, "p1")
    end

    test "refuse si match déjà démarré" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1")
      GameMatch.add_player(match.match_id, "p2")
      GameMatch.start_match(match.match_id)
      assert {:error, :match_already_started} = GameMatch.add_player(match.match_id, "p3")
    end
  end

  describe "start_match/1" do
    test "démarre un match avec 2 joueurs" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1")
      GameMatch.add_player(match.match_id, "p2")
      assert {:ok, started} = GameMatch.start_match(match.match_id)
      assert started.status == :ready
    end

    test "refuse avec 1 seul joueur" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:error, :not_enough_players} = GameMatch.start_match(match.match_id)
    end
  end

  describe "start_set/1 et roll_dice/2 (Normal)" do
    test "démarre un set et lance les dés" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set_started} = GameMatch.start_set(match.match_id)
      assert set_started.status == :set_in_progress
      assert set_started.current_set == 1

      # Lancer pour le premier joueur (selon turn order)
      first_player_id = List.first(set_started.current_set_state.turn_order)
      {:ok, result} = GameMatch.roll_dice(match.match_id, first_player_id)
      assert result.roll.player_id == first_player_id
      assert length(result.roll.dice) == 2
      assert result.roll.sum >= 2 and result.roll.sum <= 12

      {:ok, after_first_roll} = GameMatch.get_match(match.match_id)
      assert after_first_roll.current_set_state.current_turn_index == 1
      assert Enum.at(after_first_roll.current_set_state.turn_order, 1) != first_player_id
    end

    test "refuse lancer hors tour" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      GameMatch.start_set(match.match_id)

      # Le deuxième joueur ne devrait pas pouvoir lancer en premier
      {:ok, current} = GameMatch.get_match(match.match_id)
      second_player_id = Enum.at(current.current_set_state.turn_order, 1)
      assert {:error, :not_your_turn} = GameMatch.roll_dice(match.match_id, second_player_id)
    end

    test "roll_id identique rejoue sans nouveau tirage (idempotence)" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set_started} = GameMatch.start_set(match.match_id)
      first_player_id = List.first(set_started.current_set_state.turn_order)

      # Premier lancer avec roll_id : tirage réel, roll_id rediffusé.
      {:ok, first} = GameMatch.roll_dice(match.match_id, first_player_id, "roll-abc-123")
      assert first.roll.player_id == first_player_id
      assert first.roll[:roll_id] == "roll-abc-123"
      refute Map.get(first, :duplicate, false)

      # Retry avec le MÊME roll_id : même dés, flag duplicate, pas de re-tirage
      # (même si le tour a avancé, pas d'erreur already_rolled/not_your_turn).
      {:ok, retry} = GameMatch.roll_dice(match.match_id, first_player_id, "roll-abc-123")
      assert retry.roll.dice == first.roll.dice
      assert retry.roll.sum == first.roll.sum
      assert retry.duplicate == true

      # Un SEUL lancer enregistré pour ce joueur (pas de double roll).
      {:ok, current} = GameMatch.get_match(match.match_id)
      assert map_size(current.current_set_state.rolls) == 1

      # roll_id différent du même joueur = gardes habituelles inchangées
      # (ici le tour a avancé : not_your_turn passe avant already_rolled).
      assert {:error, :not_your_turn} =
               GameMatch.roll_dice(match.match_id, first_player_id, "roll-autre-456")
    end

    test "roll_dice/2 historique sans roll_id inchangé" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set_started} = GameMatch.start_set(match.match_id)
      first_player_id = List.first(set_started.current_set_state.turn_order)
      assert {:ok, %{roll: roll}} = GameMatch.roll_dice(match.match_id, first_player_id)
      assert length(roll.dice) == 2
    end
  end

  describe "vote_target/3 (Cible)" do
    test "vote pour la cible" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)
      assert set.current_set_state.vote_phase == true

      # Voter
      first_player = List.first(set.current_set_state.turn_order)
      {:ok, updated} = GameMatch.vote_target(match.match_id, first_player, 7)
      assert map_size(updated.current_set_state.votes) == 1
    end

    test "refuse double vote" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      first_player = List.first(set.current_set_state.turn_order)
      GameMatch.vote_target(match.match_id, first_player, 7)
      assert {:error, :already_voted} = GameMatch.vote_target(match.match_id, first_player, 8)
    end

    test "paramètres de vote figés à la création (défauts 20s/5s/average)" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      assert match.vote_timeout_ms == 20_000
      assert match.vote_result_delay_ms == 5_000
      assert match.target_vote_mode == "average"
    end

    test "ouverture du set pose la deadline globale de vote" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      css = set.current_set_state
      assert css.vote_phase == true
      assert %DateTime{} = css.vote_deadline
      assert is_nil(css.vote_result)
      assert is_nil(css.vote_result_until)
    end

    test "rejette les votes non-entiers sans crasher (garde de type)" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      first_player = List.first(set.current_set_state.turn_order)
      assert {:error, :invalid_target} = GameMatch.vote_target(match.match_id, first_player, "7")
      assert {:error, :invalid_target} = GameMatch.vote_target(match.match_id, first_player, 7.0)
      assert {:error, :invalid_target} = GameMatch.vote_target(match.match_id, first_player, nil)
      # Le GenServer survit : un vote valide passe toujours après.
      assert {:ok, _} = GameMatch.vote_target(match.match_id, first_player, 7)
    end

    test "rejette les votes hors intervalle [dés, dés × faces]" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      first_player = List.first(set.current_set_state.turn_order)
      # 2 dés à 6 faces : intervalle valide 2..12
      assert {:error, :invalid_target} = GameMatch.vote_target(match.match_id, first_player, 1)
      assert {:error, :invalid_target} = GameMatch.vote_target(match.match_id, first_player, 13)
      assert {:ok, _} = GameMatch.vote_target(match.match_id, first_player, 2)
    end

    test "dernier vote : cible + fenêtre résultat + deadline tour décalée" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      [p1, p2] = set.current_set_state.turn_order
      {:ok, _} = GameMatch.vote_target(match.match_id, p1, 5)
      {:ok, updated} = GameMatch.vote_target(match.match_id, p2, 9)

      css = updated.current_set_state
      assert css.target_value == 7
      assert css.vote_phase == false
      assert css.vote_result.target == 7
      assert css.vote_result.mode == "average"
      assert css.vote_result.auto_voted == []
      assert DateTime.compare(css.vote_result_until, DateTime.utc_now()) == :gt
      assert DateTime.compare(css.turn_deadline, css.vote_result_until) in [:gt, :eq]
      # Lancer refusé pendant la fenêtre d'affichage du résultat
      assert {:error, :vote_result_pending} = GameMatch.roll_dice(match.match_id, p1)
    end

    test "expiration du timer : auto-vote médian + clôture idempotente" do      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "cible", creator_id: "p1"})
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      [p1, _p2] = set.current_set_state.turn_order
      {:ok, _} = GameMatch.vote_target(match.match_id, p1, 4)
      send(Process.whereis(GameMatch), {:vote_timeout, match.match_id, 1})
      Process.sleep(300)

      {:ok, closed} = GameMatch.get_match(match.match_id)
      css = closed.current_set_state
      assert map_size(css.votes) == 2
      # 2 dés : milieu de [2, 12] = 7 pour le joueur manquant
      assert css.votes |> Map.values() |> Enum.sort() == [4, 7]
      assert css.target_value == 6
      assert css.vote_phase == false
      assert length(css.vote_result.auto_voted) == 1

      # Timeout périmé rejoué : sans effet (pas de double calcul)
      send(Process.whereis(GameMatch), {:vote_timeout, match.match_id, 1})
      Process.sleep(200)
      {:ok, again} = GameMatch.get_match(match.match_id)
      assert again.current_set_state.target_value == 6
    end
  end

  describe "délais configurables (game_rules, gelés à la création)" do
    # Restaure la config après chaque test (la DB test est partagée).
    setup do
      on_exit(fn ->
        try do
          {:ok, rule} = GameHub.GameRules.get_rules("dice", "normal")
          cleaned = Map.drop(rule.config, ["turn_timeout_seconds", "auto_next_set_delay_seconds", "leave_grace_seconds"])
          GameHub.GameRules.update_config("dice", "normal", cleaned)
        rescue
          _ -> :ok
        end
      end)
      :ok
    end

    test "défauts : auto-next 4s, grâce 20s" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      assert match.auto_next_set_delay_ms == 4_000
      assert match.leave_grace_ms == 20_000
    end

    test "valeurs admin appliquées aux nouveaux matchs, anciens gelés" do
      {:ok, rule} = GameHub.GameRules.get_rules("dice", "normal")
      {:ok, _} = GameHub.GameRules.update_config("dice", "normal", Map.merge(rule.config, %{
        "turn_timeout_seconds" => 45,
        "auto_next_set_delay_seconds" => 6,
        "leave_grace_seconds" => 30
      }))

      {:ok, fresh} = GameMatch.create_match(%{game_type: "dice", rule_type: "normal", creator_id: "p1"})
      assert fresh.turn_timeout_ms == 45_000
      assert fresh.auto_next_set_delay_ms == 6_000
      assert fresh.leave_grace_ms == 30_000
    end

    test "changeset rejette les délais hors bornes" do
      alias GameHub.Games.GameRule
      base = %{"min_sets" => 1, "max_sets" => 11, "default_sets" => 3, "min_dice" => 1,
        "max_dice" => 5, "dice_faces" => 6, "min_bet" => 100, "max_bet" => 500_000,
        "min_players" => 2, "max_players" => 5}
      rule = %GameRule{game_type: "dice", rule_type: "normal", config: base}

      ok_cs = GameRule.config_changeset(rule, Map.merge(base, %{
        "turn_timeout_seconds" => 60, "auto_next_set_delay_seconds" => 5, "leave_grace_seconds" => 20
      }))
      assert ok_cs.valid?

      ko_cs = GameRule.config_changeset(rule, Map.merge(base, %{
        "turn_timeout_seconds" => 5, "auto_next_set_delay_seconds" => 60, "leave_grace_seconds" => 1
      }))
      refute ko_cs.valid?
    end
  end

  describe "evaluate_set - Normal" do
    test "détermine le gagnant d'un set normal" do
      {:ok, match} = GameMatch.create_match(%{
        game_type: "dice", rule_type: "normal", sets_count: 1, creator_id: "p1"
      })
      GameMatch.add_player(match.match_id, "p1", "P1")
      GameMatch.add_player(match.match_id, "p2", "P2")
      GameMatch.start_match(match.match_id)
      {:ok, set} = GameMatch.start_set(match.match_id)

      # Simuler les lancers des 2 joueurs
      [p1_id, p2_id] = set.current_set_state.turn_order

      {:ok, _} = GameMatch.roll_dice(match.match_id, p1_id)
      {:ok, result} = GameMatch.roll_dice(match.match_id, p2_id)

      # Le set devrait être évalué
      assert result.set_result in [:winner, :tie] or match?({:winner, _}, result.set_result)
    end
  end

  describe "get_match/1" do
    test "récupère un match existant" do
      {:ok, match} = GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      assert {:ok, retrieved} = GameMatch.get_match(match.match_id)
      assert retrieved.match_id == match.match_id
    end

    test "retourne erreur pour match inexistant" do
      assert {:error, :match_not_found} = GameMatch.get_match("nonexistent")
    end
  end

  describe "list_active_matches/0" do
    test "liste les matchs actifs" do
      GameMatch.create_match(%{game_type: "dice", creator_id: "p1"})
      matches = GameMatch.list_active_matches()
      assert length(matches) >= 1
    end
  end
end
