# ==================================
# WIWIGA - Schéma Audit Log
# ==================================
# Auteur: Franck Arlos CHENDJOU

defmodule GameHub.Audit.AuditLog do
  @moduledoc """
  Schéma pour les logs d'audit.
  
  Trace toutes les actions sensibles :
  - Transactions financières
  - Actions admin
  - Changements de sécurité
  - Signaux de fraude
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :id, autogenerate: true}
  schema "audit_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :string
    field :changes, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string
    field :metadata, :map, default: %{}
    
    belongs_to :user, GameHub.Users.User
    
    timestamps()
  end
  
  @doc """
  Changeset pour création de log d'audit.
  """
  def create_changeset(audit_log \\ %__MODULE__{}, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id, :action, :entity_type, :entity_id,
      :changes, :ip_address, :user_agent, :metadata
    ])
    |> validate_required([:action, :entity_type])
    |> validate_inclusion(:action, all_actions())
  end
  
  defp all_actions do
    [
      "deposit", "withdrawal", "bet", "winnings",
      "user_created", "user_updated", "user_deleted",
      "kyc_verified", "kyc_rejected",
      "self_exclusion", "limit_updated",
      "admin_action", "system_action"
    ]
  end
end
