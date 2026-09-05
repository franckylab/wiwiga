# ==================================
# WIWIGA - Schéma Responsible Gaming Limits
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.ResponsibleGaming.ResponsibleGamingLimit do
  @moduledoc """
  Schéma pour les limites de jeu responsable.
  
  Conformité légale MINFI :
  - Limites de dépôt/perte
  - Auto-exclusion
  - Rappels de réalité
  - Limites de session
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  schema "responsible_gaming_limits" do
    field :daily_deposit_limit, :integer
    field :daily_loss_limit, :integer
    field :weekly_loss_limit, :integer
    field :monthly_loss_limit, :integer
    # Total misé par jour (jetons) — sommé sur toutes les mises, gains inclus
    # dans le calcul de perte nette mais pas dans le wager.
    field :daily_wager_limit, :integer
    # Mise maximale par coup (jetons) — borne le montant d'une seule mise.
    field :max_bet_amount, :integer
    # Participations payantes par jour (1 mise = 1 participation).
    field :daily_matches_limit, :integer
    field :session_time_limit_minutes, :integer, default: 120
    field :reality_check_interval_minutes, :integer, default: 30
    field :self_exclusion_until, :utc_datetime
    field :self_exclusion_reason, :string
    field :cooling_off_until, :utc_datetime
    field :is_active, :boolean, default: true
    # Hausses différées 24h (standard) : baisses immédiates, hausses en attente.
    field :pending_config, :map, default: %{}
    field :pending_effective_at, :utc_datetime

    belongs_to :user, GameHub.Users.User

    timestamps()
  end
  
  @doc """
  Changeset pour création/modification des limites.
  """
  def changeset(limit \\ %__MODULE__{}, attrs) do
    limit
    |> cast(attrs, [
      :user_id, :daily_deposit_limit, :daily_loss_limit,
      :weekly_loss_limit, :monthly_loss_limit,
      :daily_wager_limit, :max_bet_amount, :daily_matches_limit,
      :session_time_limit_minutes, :reality_check_interval_minutes,
      :self_exclusion_until, :self_exclusion_reason,
      :cooling_off_until, :is_active,
      :pending_config, :pending_effective_at
    ])
    |> validate_required([:user_id])
    |> validate_number(:session_time_limit_minutes, greater_than: 0, less_than_or_equal_to: 1440)
    |> validate_number(:reality_check_interval_minutes, greater_than: 0, less_than_or_equal_to: 1440)
    |> validate_number(:daily_deposit_limit, greater_than: 0)
    |> validate_number(:daily_loss_limit, greater_than: 0)
    |> validate_number(:weekly_loss_limit, greater_than: 0)
    |> validate_number(:monthly_loss_limit, greater_than: 0)
    |> validate_number(:daily_wager_limit, greater_than: 0)
    |> validate_number(:max_bet_amount, greater_than: 0)
    |> validate_number(:daily_matches_limit, greater_than: 0)
    |> validate_limits_coherence()
  end

  # Cohérence : périodes longues >= périodes courtes (évite une limite
  # hebdo inférieure à la limite journalière, inapplicable).
  defp validate_limits_coherence(changeset) do
    daily = get_field(changeset, :daily_loss_limit)
    weekly = get_field(changeset, :weekly_loss_limit)
    monthly = get_field(changeset, :monthly_loss_limit)

    changeset
    |> maybe_add_error(is_integer(daily) and is_integer(weekly) and weekly < daily,
      :weekly_loss_limit, "doit être >= à la limite journalière")
    |> maybe_add_error(is_integer(weekly) and is_integer(monthly) and monthly < weekly,
      :monthly_loss_limit, "doit être >= à la limite hebdomadaire")
    |> maybe_add_error(is_integer(daily) and is_integer(monthly) and monthly < daily,
      :monthly_loss_limit, "doit être >= à la limite journalière")
  end

  defp maybe_add_error(changeset, false, _field, _msg), do: changeset
  defp maybe_add_error(changeset, _, field, msg), do: add_error(changeset, field, msg)
end
