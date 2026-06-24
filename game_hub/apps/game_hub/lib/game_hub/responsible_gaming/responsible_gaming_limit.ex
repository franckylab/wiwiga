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
    field :session_time_limit_minutes, :integer, default: 120
    field :reality_check_interval_minutes, :integer, default: 30
    field :self_exclusion_until, :utc_datetime
    field :self_exclusion_reason, :string
    field :cooling_off_until, :utc_datetime
    field :is_active, :boolean, default: true
    
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
      :session_time_limit_minutes, :reality_check_interval_minutes,
      :self_exclusion_until, :self_exclusion_reason,
      :cooling_off_until, :is_active
    ])
    |> validate_required([:user_id])
    |> validate_number(:session_time_limit_minutes, greater_than: 0)
    |> validate_number(:reality_check_interval_minutes, greater_than: 0)
    |> validate_number(:daily_deposit_limit, greater_than: 0)
    |> validate_number(:daily_loss_limit, greater_than: 0)
  end
end
