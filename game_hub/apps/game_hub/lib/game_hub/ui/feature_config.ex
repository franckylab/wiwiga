defmodule GameHub.UI.FeatureConfig do
  @moduledoc """
  Configuration des fonctionnalités de l'application WIWIGA.
  
  Paramètres fonctionnels configurables via le dashboard admin:
  - Mode maintenance
  - Limites de dépôt/retrait
  - Paramètres KYC
  - Timeouts et sessions
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, except: [:__meta__, :maintenance_message]}
  
  schema "app_feature_configs" do
    # Mode maintenance
    field :maintenance_mode, :boolean, default: false
    field :maintenance_message, :string, default: "WIWIGA est en maintenance. Veuillez réessayer plus tard."
    field :registration_enabled, :boolean, default: true
    
    # Dépôt
    field :min_deposit_amount, :integer, default: 500
    field :max_deposit_amount, :integer, default: 1_000_000
    
    # Retrait
    field :min_withdrawal_amount, :integer, default: 1_000
    field :max_withdrawal_amount, :integer, default: 5_000_000
    
    # KYC
    field :kyc_required_threshold, :integer, default: 100_000
    
    # Limites
    field :max_games_per_user, :integer, default: 10
    
    # Timeouts (ms)
    field :websocket_timeout_ms, :integer, default: 30_000
    field :session_timeout_ms, :integer, default: 1_800_000
    field :reality_check_interval_ms, :integer, default: 1_800_000
    
    # Auto-exclusion
    field :self_exclusion_options, {:array, :integer}, default: [24, 168, 720]
    
    # Contact
    field :support_email, :string, default: "support@wiwiga.cm"
    field :support_phone, :string, default: "+237 600 000 000"
    field :terms_url, :string, default: "https://wiwiga.cm/terms"
    field :privacy_url, :string, default: "https://wiwiga.cm/privacy"
    
    belongs_to :updated_by, User
    
    timestamps()
  end
  
  def get_config do
    case Repo.one(from(f in __MODULE__, limit: 1)) do
      nil -> create_default_config()
      config -> config
    end
  end
  
  def update_config(attrs) do
    config = get_config()
    
    config
    |> changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_config} ->
        GameHubWeb.Endpoint.broadcast!("feature:update", %{
          config: Map.from_struct(updated_config)
        })
        {:ok, updated_config}
      error -> error
    end
  end
  
  @doc """
  Vérifie si l'application est en mode maintenance.
  """
  def maintenance_active? do
    get_config().maintenance_mode
  end
  
  @doc """
  Vérifie si les inscriptions sont ouvertes.
  """
  def registration_open? do
    !maintenance_active?() && get_config().registration_enabled
  end
  
  defp create_default_config do
    %__MODULE__{}
    |> changeset(%{})
    |> Repo.insert!()
  end
  
  defp changeset(feature_config, attrs) do
    feature_config
    |> cast(attrs, [
      :maintenance_mode, :maintenance_message, :registration_enabled,
      :min_deposit_amount, :max_deposit_amount,
      :min_withdrawal_amount, :max_withdrawal_amount,
      :kyc_required_threshold, :max_games_per_user,
      :websocket_timeout_ms, :session_timeout_ms, :reality_check_interval_ms,
      :self_exclusion_options,
      :support_email, :support_phone, :terms_url, :privacy_url,
      :updated_by_id
    ])
    |> validate_required([:maintenance_mode, :registration_enabled])
    |> validate_number(:min_deposit_amount, greater_than_or_equal_to: 0)
    |> validate_number(:max_deposit_amount, greater_than_or_equal_to: 0)
    |> validate_number(:min_withdrawal_amount, greater_than_or_equal_to: 0)
    |> validate_number(:max_withdrawal_amount, greater_than_or_equal_to: 0)
    |> validate_format(:support_email, ~r/@/)
  end
end
