defmodule GameHub.UI.GameConfig do
  @moduledoc """
  Configuration spécifique à chaque jeu.
  
  Permet de configurer indépendamment chaque jeu:
  - Mises min/max
  - Commission
  - Timeouts
  - Paramètres spécifiques (JSON)
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @derive {Jason.Encoder, except: [:__meta__]}
  
  schema "game_specific_configs" do
    field :game_type, :string
    field :enabled, :boolean, default: true
    
    field :min_bet, :integer, default: 100
    field :max_bet, :integer, default: 500_000
    field :max_players, :integer, default: 2
    field :commission_rate, :float, default: 0.05
    
    field :game_settings, :map, default: %{}
    
    field :matchmaking_timeout_ms, :integer, default: 30_000
    field :turn_timeout_ms, :integer, default: 15_000
    
    belongs_to :updated_by, User
    
    timestamps()
  end
  
  def get_config(game_type) do
    case Repo.get_by(__MODULE__, game_type: game_type) do
      nil -> create_default_config(game_type)
      config -> config
    end
  end
  
  def list_configs do
    Repo.all(from(g in __MODULE__, order_by: g.game_type))
  end
  
  def create_or_update(game_type, attrs) do
    config = get_config(game_type)
    
    config
    |> changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, updated_config} ->
        GameHubWeb.Endpoint.broadcast!("game_config:update:#{game_type}", %{
          config: Map.from_struct(updated_config)
        })
        {:ok, updated_config}
      error -> error
    end
  end
  
  defp create_default_config(game_type) do
    %__MODULE__{game_type: game_type}
    |> changeset(%{})
    |> Repo.insert!()
  end
  
  defp changeset(game_config, attrs) do
    game_config
    |> cast(attrs, [
      :game_type, :enabled, :min_bet, :max_bet, :max_players,
      :commission_rate, :game_settings, :matchmaking_timeout_ms,
      :turn_timeout_ms, :updated_by_id
    ])
    |> validate_required([:game_type])
    |> validate_number(:min_bet, greater_than_or_equal_to: 0)
    |> validate_number(:max_bet, greater_than_or_equal_to: 0)
    |> validate_number(:commission_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end


defmodule GameHub.UI.PaymentConfig do
  @moduledoc """
  Configuration des méthodes de paiement.
  
  Permet de configurer chaque provider:
  - Campay, MTN MoMo, Orange Money
  - Montants min/max
  - Clés API (à chiffrer en production)
  - Frais de transaction
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @derive {Jason.Encoder, except: [:__meta__, :api_key, :api_secret]}
  
  schema "payment_configs" do
    field :provider, :string
    field :enabled, :boolean, default: true
    
    field :min_amount, :integer, default: 500
    field :max_amount, :integer, default: 1_000_000
    
    field :api_key, :string
    field :api_secret, :string
    field :api_url, :string
    field :webhook_url, :string
    
    field :provider_settings, :map, default: %{}
    
    field :transaction_fee_percentage, :float, default: 0.0
    field :transaction_fee_fixed, :integer, default: 0
    
    belongs_to :updated_by, User
    
    timestamps()
  end
  
  def get_config(provider) do
    case Repo.get_by(__MODULE__, provider: provider) do
      nil -> create_default_config(provider)
      config -> config
    end
  end
  
  def list_enabled_configs do
    Repo.all(from(p in __MODULE__, where: p.enabled == true, order_by: p.provider))
  end
  
  def create_or_update(provider, attrs) do
    config = get_config(provider)
    
    config
    |> changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, updated_config} ->
        GameHubWeb.Endpoint.broadcast!("payment_config:update:#{provider}", %{
          config: Map.drop(Map.from_struct(updated_config), [:api_key, :api_secret])
        })
        {:ok, updated_config}
      error -> error
    end
  end
  
  defp create_default_config(provider) do
    %__MODULE__{provider: provider}
    |> changeset(%{})
    |> Repo.insert!()
  end
  
  defp changeset(payment_config, attrs) do
    payment_config
    |> cast(attrs, [
      :provider, :enabled, :min_amount, :max_amount,
      :api_key, :api_secret, :api_url, :webhook_url,
      :provider_settings, :transaction_fee_percentage,
      :transaction_fee_fixed, :updated_by_id
    ])
    |> validate_required([:provider])
    |> validate_number(:min_amount, greater_than_or_equal_to: 0)
    |> validate_number(:max_amount, greater_than_or_equal_to: 0)
    |> validate_number(:transaction_fee_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end
