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

  @type t :: %__MODULE__{}
  
  @derive {Jason.Encoder, only: [:id, :action, :entity_type, :entity_id, :changes, :ip_address, :user_agent, :metadata, :user_id, :inserted_at, :updated_at]}
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
      # Auth
      "otp_sent", "otp_email_sent", "otp_verified", "login", "logout", "logout_all",
      "password_login", "password_login_failed", "password_changed",
      "token_refresh", "token_replay_detected", "multi_account_detected",
      "rate_limited", "session_restored", "auth_settings_updated",
      # Wallet
      "deposit", "withdrawal", "bet", "winnings",
      # User
      "user_created", "user_updated", "user_deleted",
      # KYC
      "kyc_verified", "kyc_rejected",
      # Responsible gaming
      "self_exclusion", "limit_updated",
      # Admin
      "admin_action", "system_action",
      # Payment
      "payment_failed"
    ]
  end

  @doc """
  Helper pour créer un log d'audit rapidement.
  
  ## Parameters
    - action: type d'action (voir all_actions/0)
    - user_id: ID de l'utilisateur qui a effectué l'action
    - entity_type: type d'entité concernée
    - entity_id: ID de l'entité
    - metadata: données additionnelles
  """
  @spec log(String.t(), integer() | nil, String.t(), String.t(), map()) :: {:ok, t()} | {:error, term()}
  def log(action, user_id, entity_type, entity_id, metadata \\ %{}) do
    %__MODULE__{}
    |> create_changeset(%{
      action: action,
      user_id: user_id,
      entity_type: entity_type,
      entity_id: entity_id,
      metadata: metadata
    })
    |> GameHub.Repo.insert()
  end
end
