# ==================================
# WIWIGA - Schéma Game Timeout Config
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Games.GameTimeoutConfig do
  @moduledoc """
  Schéma pour la configuration des timeouts de jeu.
  
  Gère les politiques de déconnexion :
  - Délai de grâce
  - Action en cas de timeout
  - Distribution des mises
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  schema "game_timeout_configs" do
    field :game_type, :string
    field :grace_period_seconds, :integer, default: 120
    field :action_on_timeout, :string, default: "forfeit"
    field :forfeit_distribution, :string, default: "to_winner"
    field :reconnect_allowed, :boolean, default: true
    field :max_reconnect_attempts, :integer, default: 3
    field :is_active, :boolean, default: true
    
    timestamps()
  end
  
  @doc """
  Changeset pour création/modification de la config timeout.
  """
  def changeset(config \\ %__MODULE__{}, attrs) do
    config
    |> cast(attrs, [
      :game_type, :grace_period_seconds, :action_on_timeout,
      :forfeit_distribution, :reconnect_allowed,
      :max_reconnect_attempts, :is_active
    ])
    |> validate_required([:game_type, :grace_period_seconds, :action_on_timeout])
    |> validate_number(:grace_period_seconds, greater_than: 0)
    |> validate_inclusion(:action_on_timeout, ["forfeit", "refund", "pause"])
    |> validate_inclusion(:forfeit_distribution, ["to_winner", "split", "pool"])
    |> validate_number(:max_reconnect_attempts, greater_than: 0)
  end
end
