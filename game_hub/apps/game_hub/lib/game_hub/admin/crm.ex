# ==================================
# WIWIGA - Module Admin CRM
# ==================================
# Module: GameHub.Admin.CRM
# Description: CRM joueurs - segmentation, VIP, notes, détection risques

defmodule GameHub.Admin.CRM do
  @moduledoc """
  Module CRM pour la gestion des joueurs.
  
  Fonctionnalités:
  - Segmentation joueurs (VIP, high-rollers, nouveaux, inactifs, à risque)
  - Résumé complet d'un joueur
  - Notes admin sur les joueurs
  - Gestion des tiers VIP
  - Détection des comportements à risque
  """

  alias GameHub.Repo
  alias GameHub.Users.User
  alias GameHub.Wallet.WalletTransaction
  alias GameHub.GameStats.GameStat
  alias GameHub.Audit.AuditLog
  import Ecto.Query

  # ========================================
  # Segments joueurs
  # ========================================

  @doc """
  Retourne les segments de joueurs avec compteurs et volumes.
  """
  @spec get_player_segments() :: list(map())
  def get_player_segments do
    total_users = Repo.one(from u in User, select: count(u.id))

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

    # VIP: top 5% par volume de mises
    vip_count = Repo.one(
      from gs in GameStat,
        select: count(gs.user_id, :distinct),
        having: sum(gs.total_wagered) > fragment("(SELECT percentile_cont(0.95) WITHIN GROUP (ORDER BY total_wagered) FROM game_stats)")
    ) |> case do
      nil -> 0
      count -> count
    end

    # High-rollers: mises > 500K centimes
    high_rollers = Repo.one(
      from gs in GameStat,
        where: gs.total_wagered > 500_000,
        select: count(gs.user_id, :distinct)
    )

    # Nouveaux (inscrits depuis 7 jours)
    new_players = Repo.one(
      from u in User,
        where: u.inserted_at >= ^seven_days_ago,
        select: count(u.id)
    )

    # Inactifs (pas connecté depuis 30 jours)
    inactive = Repo.one(
      from u in User,
        where: u.is_active == true and
               (is_nil(u.last_login_at) or u.last_login_at < ^thirty_days_ago),
        select: count(u.id)
    )

    # À risque
    at_risk = count_at_risk_players()

    # KYC vérifiés
    kyc_verified = Repo.one(
      from u in User,
        where: u.has_verified_kyc == true,
        select: count(u.id)
    )

    [
      %{key: "total", label: "Total joueurs", count: total_users, color: "blue"},
      %{key: "vip", label: "VIP", count: vip_count, color: "gold"},
      %{key: "high_rollers", label: "High-rollers", count: high_rollers, color: "purple"},
      %{key: "new_players", label: "Nouveaux (7j)", count: new_players, color: "green"},
      %{key: "inactive", label: "Inactifs (30j+)", count: inactive, color: "gray"},
      %{key: "at_risk", label: "À risque", count: at_risk, color: "red"},
      %{key: "kyc_verified", label: "KYC vérifié", count: kyc_verified, color: "teal"}
    ]
  end

  # ========================================
  # Résumé joueur
  # ========================================

  @doc """
  Résumé complet d'un joueur pour le CRM.
  """
  @spec get_player_summary(integer()) :: {:ok, map()} | {:error, term()}
  def get_player_summary(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        # Stats de jeu
        game_stats = Repo.one(
          from gs in GameStat,
            where: gs.user_id == ^user_id,
            select: %{
              total_matches: coalesce(sum(gs.matches_played), 0),
              total_wagered: coalesce(sum(gs.total_wagered), 0),
              total_won: coalesce(sum(gs.total_won_net), 0),
              games_played: count(gs.id)
            }
        ) || %{total_matches: 0, total_wagered: 0, total_won: 0, games_played: 0}

        # Transactions financières
        financial = Repo.all(
          from t in WalletTransaction,
            where: t.user_id == ^user_id,
            group_by: t.type,
            select: %{type: t.type, total: sum(t.amount), count: count(t.id)}
        )

        # Notes admin
        notes_count = Repo.one(
          from n in "player_notes",
            where: n.user_id == ^user_id,
            select: count(n.id)
        )

        # Tier VIP
        vip_tier = Repo.one(
          from v in "player_vip_tiers",
            where: v.user_id == ^user_id,
            order_by: [desc: v.inserted_at],
            limit: 1,
            select: %{tier: v.tier, assigned_at: v.assigned_at, expires_at: v.expires_at}
        )

        # Score de risque
        risk_score = calculate_risk_score(user, game_stats, financial)

        {:ok, %{
          user: %{
            id: user.id,
            phone: user.phone,
            name: user.name,
            email: user.email,
            role: user.role,
            balance: user.balance,
            token_balance: user.token_balance,
            is_active: user.is_active,
            has_verified_kyc: user.has_verified_kyc,
            self_excluded: user.self_excluded,
            inserted_at: user.inserted_at,
            last_login_at: user.last_login_at
          },
          game_stats: game_stats,
          financial: Map.new(financial, fn f -> {f.type, %{total: f.total, count: f.count}} end),
          notes_count: notes_count,
          vip_tier: vip_tier,
          risk_score: risk_score,
          risk_level: risk_level(risk_score)
        }}
    end
  end

  # ========================================
  # Notes admin
  # ========================================

  @doc """
  Ajoute une note sur un joueur.
  """
  @spec add_note(integer(), integer(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def add_note(user_id, admin_id, note, category \\ "general") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    result = Repo.insert_all("player_notes", [
      %{
        user_id: user_id,
        admin_id: admin_id,
        note: note,
        category: category,
        inserted_at: now,
        updated_at: now
      }
    ], returning: true)

    case result do
      {1, [entry]} ->
        AuditLog.log("admin_action", admin_id, "users", to_string(user_id), %{
          "action" => "add_note",
          "category" => category
        })
        {:ok, entry}
      _ -> {:error, "Failed to add note"}
    end
  end

  @doc """
  Liste les notes d'un joueur avec pagination.
  """
  @spec list_notes(integer(), integer(), integer()) :: list()
  def list_notes(user_id, page \\ 1, limit \\ 20) do
    offset = (page - 1) * limit

    Repo.all(
      from n in "player_notes",
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: n.id,
          note: n.note,
          category: n.category,
          admin_id: n.admin_id,
          inserted_at: n.inserted_at
        }
    )
  end

  # ========================================
  # VIP
  # ========================================

  @doc """
  Top joueurs par volume de mises.
  """
  @spec get_vip_players(integer()) :: list()
  def get_vip_players(limit \\ 50) do
    Repo.all(
      from gs in GameStat,
        join: u in User, on: gs.user_id == u.id,
        group_by: [gs.user_id, u.id],
        order_by: [desc: sum(gs.total_wagered)],
        limit: ^limit,
        select: %{
          user_id: gs.user_id,
          name: u.name,
          phone: u.phone,
          total_wagered: sum(gs.total_wagered),
          total_won: sum(gs.total_won_net),
          matches: sum(gs.matches_played),
          balance: u.balance,
          has_kyc: u.has_verified_kyc
        }
    )
  end

  @doc """
  Assigne un tier VIP à un joueur.
  """
  @spec set_vip_tier(integer(), String.t(), integer(), integer() | nil) :: {:ok, map()} | {:error, term()}
  def set_vip_tier(user_id, tier, assigned_by, expires_in_days \\ 90) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, expires_in_days * 24 * 3600, :second)

    result = Repo.insert_all("player_vip_tiers", [
      %{
        user_id: user_id,
        tier: tier,
        assigned_by: assigned_by,
        assigned_at: now,
        expires_at: expires_at,
        inserted_at: now,
        updated_at: now
      }
    ], returning: true)

    case result do
      {1, [entry]} ->
        AuditLog.log("admin_action", assigned_by, "users", to_string(user_id), %{
          "action" => "set_vip_tier",
          "tier" => tier
        })
        {:ok, entry}
      _ -> {:error, "Failed to set VIP tier"}
    end
  end

  # ========================================
  # Joueurs à risque
  # ========================================

  @doc """
  Joueurs avec comportement à risque détecté.
  """
  @spec get_at_risk_players() :: list()
  def get_at_risk_players do
    # Joueurs avec self_exclusion ou ratio pertes/dépôts élevé
    Repo.all(
      from u in User,
        where: u.is_active == true,
        select: %{
          user_id: u.id,
          name: u.name,
          phone: u.phone,
          balance: u.balance,
          self_excluded: u.self_excluded,
          last_login: u.last_login_at
        }
    )
    |> Enum.filter(fn player ->
      player.self_excluded == true or player.balance < 0
    end)
  end

  # ========================================
  # Helpers privés
  # ========================================

  defp count_at_risk_players do
    Repo.one(
      from u in User,
        where: u.is_active == true and
               (u.self_excluded == true or u.balance < 0),
        select: count(u.id)
    )
  end

  defp calculate_risk_score(user, game_stats, financial) do
    score = 0

    # Auto-exclu = risque max
    score = if user.self_excluded, do: score + 50, else: score

    # Ratio mises/dépôts élevé
    deposit_total = case Map.get(financial, "deposit") do
      %{total: t} when t > 0 -> t
      _ -> 1
    end

    wager_ratio = if deposit_total > 0, do: game_stats.total_wagered / deposit_total, else: 0
    score = if wager_ratio > 10, do: score + 30, else: score
    score = if wager_ratio > 5, do: score + 15, else: score

    # Solde négatif
    score = if user.balance < 0, do: score + 20, else: score

    # Pas de KYC
    score = if not user.has_verified_kyc, do: score + 10, else: score

    min(score, 100)
  end

  defp risk_level(score) do
    cond do
      score >= 70 -> "critical"
      score >= 40 -> "high"
      score >= 20 -> "medium"
      true -> "low"
    end
  end
end
