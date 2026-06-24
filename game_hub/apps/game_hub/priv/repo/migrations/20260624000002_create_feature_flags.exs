# ==================================
# WIWIGA - Migration Feature Flags
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Repo.Migrations.CreateFeatureFlags do
  use Ecto.Migration

  def up do
    create table(:feature_flags, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :flag_name, :string, null: false
      add :description, :text
      add :enabled, :boolean, default: false, null: false
      add :percentage_rollout, :integer, default: 0
      add :user_ids_whitelist, {:array, :bigint}, default: []
      add :user_ids_blacklist, {:array, :bigint}, default: []
      add :environment, :string, default: "all"
      add :created_by, :bigint
      timestamps()
    end

    create unique_index(:feature_flags, [:flag_name])
    create index(:feature_flags, [:enabled])
    create index(:feature_flags, [:environment])
  end

  def down do
    drop table(:feature_flags)
  end
end
