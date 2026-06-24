# ==================================
# WIWIGA - Schéma Feature Flag
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.FeatureFlags.FeatureFlag do
  @moduledoc """
  Schéma pour les feature flags.
  
  Permet le déploiement progressif avec :
  - Rollout par pourcentage
  - Whitelist/Blacklist utilisateurs
  - Kill switch instantané
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  schema "feature_flags" do
    field :flag_name, :string
    field :description, :string
    field :enabled, :boolean, default: false
    field :percentage_rollout, :integer, default: 0
    field :user_ids_whitelist, {:array, :integer}, default: []
    field :user_ids_blacklist, {:array, :integer}, default: []
    field :environment, :string, default: "all"
    field :created_by, :integer
    
    timestamps()
  end
  
  @doc """
  Changeset pour création/modification de feature flag.
  """
  def changeset(flag \\ %__MODULE__{}, attrs) do
    flag
    |> cast(attrs, [
      :flag_name, :description, :enabled, :percentage_rollout,
      :user_ids_whitelist, :user_ids_blacklist, :environment, :created_by
    ])
    |> validate_required([:flag_name, :enabled])
    |> validate_inclusion(:environment, ["all", "dev", "staging", "prod"])
    |> validate_number(:percentage_rollout, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:flag_name, name: :feature_flags_flag_name_index)
  end
end
