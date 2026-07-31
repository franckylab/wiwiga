# ==================================
# WIWIGA - Contexte Statistiques Jeux
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameStats
# Description: Agrégats stats joueurs, leaderboards, flux d'activité

defmodule GameHub.GameStats do
  @moduledoc """
  Contexte statistiques des jeux.

  ## Responsabilités
    - `record_match_result/1` : hook fin de match (upsert agrégats + événement activité)
    - `global_stats/1` : stats globales d'un jeu (cache ETS 60s)
    - `leaderboard/5` : classements par métrique × période (+ rang joueur courant)
    - `my_stats/2` : statistiques personnelles
    - `recent_activity/2` : dernières victoires publiques
  """

  import Ecto.Query

  alias GameHub.Repo
  alias GameHub.GameStats.{GameStat, ActivityEvent}
  alias GameHub.Users.User

  require Logger

  @cache_table :game_stats_cache
  @cache_ttl_ms 60_000
  @activity_retention_days 90
  @valid_metrics ~w(wins total_won biggest_win)
  @valid_periods ~w(day week month all)

  # === Enregistrement fin de match ===

  @doc """
  Enregistre le résultat d'un match dans les agrégats.

  ## Parameters
    - `attrs`: map avec
      - `:game_type` (ex: "dice")
      - `:winner_id` (integer | nil si match nul)
      - `:player_ids` (liste des joueurs)
      - `:bets` (map player_id => montant misé, centimes)
      - `:net_winnings` (gain net du gagnant, centimes)

  ## Returns
    - `:ok` (les erreurs sont loggées, jamais propagées au flux de jeu)
  """
  def record_match_result(attrs) do
    game_type = attrs[:game_type] || "dice"
    winner_id = normalize_id(attrs[:winner_id])
    player_ids = (attrs[:player_ids] || []) |> Enum.map(&normalize_id/1) |> Enum.reject(&is_nil/1)
    bets = attrs[:bets] || %{}
    net_winnings = attrs[:net_winnings] || 0
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(player_ids, fn player_id ->
      wagered = bet_amount_for(bets, player_id)

      if player_id == winner_id do
        upsert_winner(player_id, game_type, wagered, net_winnings, now)
      else
        upsert_loser(player_id, game_type, wagered, now)
      end
    end)

    # Événement public uniquement pour les victoires avec gain
    if winner_id != nil and net_winnings > 0 do
      %ActivityEvent{}
      |> ActivityEvent.changeset(%{
        game_type: game_type,
        user_id: winner_id,
        event_type: "win",
        amount: net_winnings
      })
      |> Repo.insert()

      prune_old_events(game_type)
    end

    invalidate_cache(game_type)
    :ok
  rescue
    error ->
      Logger.error("GameStats.record_match_result failed: #{inspect(error)}")
      :ok
  end

  # === Stats globales (cache ETS 60s) ===

  @doc """
  Statistiques globales d'un jeu : joueurs en ligne, parties du jour,
  total distribué du jour, plus gros gain du jour.
  """
  def global_stats(game_type) do
    cached(:global_stats, game_type, fn ->
      today_start = today_start()

      {matches_today, distributed_today, biggest_win_today} =
        from(e in ActivityEvent,
          where: e.game_type == ^game_type and e.inserted_at >= ^today_start,
          select: {count(e.id), type(coalesce(sum(e.amount), 0), :integer), coalesce(max(e.amount), 0)}
        )
        |> Repo.one()

      total_players =
        from(s in GameStat, where: s.game_type == ^game_type, select: count(s.id))
        |> Repo.one()

      %{
        players_online: players_online(game_type),
        matches_today: matches_today,
        total_distributed_today: distributed_today,
        biggest_win_today: biggest_win_today,
        total_players: total_players
      }
    end)
  end

  # === Leaderboard ===

  @doc """
  Classement d'un jeu.

  ## Parameters
    - `metric`: "wins" | "total_won" | "biggest_win"
    - `period`: "day" | "week" | "month" | "all"
    - `limit`: taille du top N
    - `current_user_id`: pour calculer `my_rank` (nil accepté)

  ## Returns
    - `{:ok, %{entries: [...], my_rank: integer | nil, my_value: integer | nil}}`
    - `{:error, :invalid_metric | :invalid_period}`
  """
  def leaderboard(game_type, metric, period, limit \\ 20, current_user_id \\ nil)

  def leaderboard(_game_type, metric, _period, _limit, _user) when metric not in @valid_metrics,
    do: {:error, :invalid_metric}

  def leaderboard(_game_type, _metric, period, _limit, _user) when period not in @valid_periods,
    do: {:error, :invalid_period}

  def leaderboard(game_type, metric, "all", limit, current_user_id) do
    metric_field = all_time_metric_field(metric)

    entries =
      from(s in GameStat,
        join: u in User, on: u.id == s.user_id,
        where: s.game_type == ^game_type and field(s, ^metric_field) > 0,
        order_by: [desc: field(s, ^metric_field), asc: s.user_id],
        limit: ^limit,
        select: %{user_id: s.user_id, name: u.name, value: field(s, ^metric_field),
                  wins: s.wins, matches_played: s.matches_played}
      )
      |> Repo.all()
      |> add_ranks()

    {my_rank, my_value} = all_time_rank(game_type, metric_field, current_user_id)

    {:ok, %{entries: entries, my_rank: my_rank, my_value: my_value}}
  end

  def leaderboard(game_type, metric, period, limit, current_user_id) do
    since = period_start(period)

    aggregated =
      from(e in ActivityEvent,
        join: u in User, on: u.id == e.user_id,
        where: e.game_type == ^game_type and e.inserted_at >= ^since,
        group_by: [e.user_id, u.name],
        select: %{user_id: e.user_id, name: u.name,
                  wins: count(e.id),
                  total_won: type(coalesce(sum(e.amount), 0), :integer),
                  biggest_win: coalesce(max(e.amount), 0)}
      )
      |> Repo.all()

    metric_key = String.to_existing_atom(metric)

    sorted =
      aggregated
      |> Enum.map(fn row -> Map.put(row, :value, Map.fetch!(row, metric_key)) end)
      |> Enum.sort_by(fn row -> {-row.value, row.user_id} end)

    entries =
      sorted
      |> Enum.take(limit)
      |> Enum.map(fn row -> Map.take(row, [:user_id, :name, :value, :wins]) end)
      |> add_ranks()

    {my_rank, my_value} =
      case normalize_id(current_user_id) do
        nil -> {nil, nil}
        uid ->
          case Enum.find_index(sorted, fn row -> row.user_id == uid end) do
            nil -> {nil, nil}
            index -> {index + 1, Enum.at(sorted, index).value}
          end
      end

    {:ok, %{entries: entries, my_rank: my_rank, my_value: my_value}}
  end

  # === Stats personnelles ===

  @doc """
  Statistiques personnelles d'un joueur pour un jeu.
  Retourne un agrégat vide si le joueur n'a jamais joué.
  """
  def my_stats(user_id, game_type) do
    case Repo.get_by(GameStat, user_id: normalize_id(user_id), game_type: game_type) do
      nil ->
        %{user_id: normalize_id(user_id), game_type: game_type, matches_played: 0,
          wins: 0, losses: 0, total_wagered: 0, total_won_net: 0, biggest_win: 0,
          current_streak: 0, best_streak: 0, last_played_at: nil, win_rate: 0.0}

      stat ->
        win_rate =
          if stat.matches_played > 0,
            do: Float.round(stat.wins / stat.matches_played * 100, 1),
            else: 0.0

        %{user_id: stat.user_id, game_type: stat.game_type,
          matches_played: stat.matches_played, wins: stat.wins, losses: stat.losses,
          total_wagered: stat.total_wagered, total_won_net: stat.total_won_net,
          biggest_win: stat.biggest_win, current_streak: stat.current_streak,
          best_streak: stat.best_streak, last_played_at: stat.last_played_at,
          win_rate: win_rate}
    end
  end

  # === Flux d'activité ===

  @doc """
  Dernières victoires publiques d'un jeu (pseudo, montant, horodatage).
  """
  def recent_activity(game_type, limit \\ 20) do
    from(e in ActivityEvent,
      join: u in User, on: u.id == e.user_id,
      where: e.game_type == ^game_type,
      order_by: [desc: e.inserted_at, desc: e.id],
      limit: ^limit,
      select: %{id: e.id, user_id: e.user_id, name: u.name, event_type: e.event_type,
                amount: e.amount, inserted_at: e.inserted_at}
    )
    |> Repo.all()
  end

  @doc """
  Joueurs en ligne pour un jeu (file d'attente Redis).
  """
  def players_online(game_type) do
    case Redix.command(GameHub.Redis, ["HLEN", "queue:#{game_type}"]) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @doc """
  Invalide le cache des stats globales d'un jeu.
  """
  def invalidate_cache(game_type) do
    ensure_cache_table()
    :ets.delete(@cache_table, {:global_stats, game_type})
    :ok
  end

  # === Fonctions Privées ===

  defp upsert_winner(user_id, game_type, wagered, net_winnings, now) do
    on_conflict =
      from(s in GameStat,
        update: [
          inc: [matches_played: 1, wins: 1,
                total_wagered: ^wagered, total_won_net: ^net_winnings],
          set: [
            biggest_win: fragment("GREATEST(?, ?)", s.biggest_win, ^net_winnings),
            best_streak: fragment("GREATEST(?, ? + 1)", s.best_streak, s.current_streak),
            current_streak: s.current_streak + 1,
            last_played_at: ^now,
            updated_at: ^now
          ]
        ]
      )

    %GameStat{}
    |> GameStat.changeset(%{
      user_id: user_id, game_type: game_type, matches_played: 1, wins: 1, losses: 0,
      total_wagered: wagered, total_won_net: net_winnings, biggest_win: net_winnings,
      current_streak: 1, best_streak: 1, last_played_at: now
    })
    |> Repo.insert(on_conflict: on_conflict, conflict_target: [:user_id, :game_type])
  end

  defp upsert_loser(user_id, game_type, wagered, now) do
    on_conflict =
      from(s in GameStat,
        update: [
          inc: [matches_played: 1, losses: 1, total_wagered: ^wagered],
          set: [current_streak: 0, last_played_at: ^now, updated_at: ^now]
        ]
      )

    %GameStat{}
    |> GameStat.changeset(%{
      user_id: user_id, game_type: game_type, matches_played: 1, wins: 0, losses: 1,
      total_wagered: wagered, total_won_net: 0, biggest_win: 0,
      current_streak: 0, best_streak: 0, last_played_at: now
    })
    |> Repo.insert(on_conflict: on_conflict, conflict_target: [:user_id, :game_type])
  end

  defp bet_amount_for(bets, player_id) do
    value = Map.get(bets, player_id) || Map.get(bets, "#{player_id}") || 0

    case value do
      %{"amount" => amount} -> amount
      %{amount: amount} -> amount
      amount when is_integer(amount) -> amount
      _ -> 0
    end
  end

  defp all_time_metric_field("wins"), do: :wins
  defp all_time_metric_field("total_won"), do: :total_won_net
  defp all_time_metric_field("biggest_win"), do: :biggest_win

  defp all_time_rank(_game_type, _field, nil), do: {nil, nil}

  defp all_time_rank(game_type, metric_field, user_id) do
    uid = normalize_id(user_id)

    case Repo.get_by(GameStat, user_id: uid, game_type: game_type) do
      nil ->
        {nil, nil}

      stat ->
        my_value = Map.fetch!(stat, metric_field)

        better =
          from(s in GameStat,
            where: s.game_type == ^game_type and field(s, ^metric_field) > ^my_value,
            select: count(s.id)
          )
          |> Repo.one()

        {better + 1, my_value}
    end
  end

  defp add_ranks(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, rank} -> Map.put(entry, :rank, rank) end)
  end

  defp period_start("day"), do: today_start()

  defp period_start("week") do
    DateTime.utc_now() |> DateTime.add(-7 * 86_400, :second) |> DateTime.truncate(:second)
  end

  defp period_start("month") do
    DateTime.utc_now() |> DateTime.add(-30 * 86_400, :second) |> DateTime.truncate(:second)
  end

  defp today_start do
    DateTime.utc_now()
    |> DateTime.to_date()
    |> DateTime.new!(~T[00:00:00], "Etc/UTC")
  end

  defp prune_old_events(game_type) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@activity_retention_days * 86_400, :second)

    from(e in ActivityEvent, where: e.game_type == ^game_type and e.inserted_at < ^cutoff)
    |> Repo.delete_all()
  end

  defp normalize_id(nil), do: nil
  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp cached(kind, game_type, compute_fn) do
    ensure_cache_table()
    key = {kind, game_type}
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        value

      _ ->
        value = compute_fn.()
        :ets.insert(@cache_table, {key, value, now + @cache_ttl_ms})
        value
    end
  end

  defp ensure_cache_table do
    case :ets.whereis(@cache_table) do
      :undefined ->
        try do
          :ets.new(@cache_table, [:named_table, :public, :set,
                                  read_concurrency: true, write_concurrency: true])
        rescue
          ArgumentError -> @cache_table
        end

      _ ->
        @cache_table
    end
  end
end
