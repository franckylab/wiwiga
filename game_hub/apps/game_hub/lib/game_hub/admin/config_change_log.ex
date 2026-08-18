# ==================================
# WIWIGA - Schéma Config Change Log
# ==================================
# Module: GameHub.Admin.ConfigChangeLog
# Description: Historique des modifications de configuration

defmodule GameHub.Admin.ConfigChangeLog do
  @moduledoc """
  Schéma pour l'historique des changements de configuration.
  Permet le tracking et le rollback des modifications.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :config_type, :config_id, :changed_by,
                                  :old_values, :new_values, :change_summary,
                                  :inserted_at]}

  @primary_key {:id, :id, autogenerate: true}
  schema "config_change_logs" do
    field :config_type, :string
    field :config_id, :integer
    field :changed_by, :integer
    field :old_values, :map, default: %{}
    field :new_values, :map, default: %{}
    field :change_summary, :string

    timestamps()
  end

  def changeset(log \\ %__MODULE__{}, attrs) do
    log
    |> cast(attrs, [:config_type, :config_id, :changed_by, :old_values, :new_values, :change_summary])
    |> validate_required([:config_type, :changed_by, :new_values])
  end
end
