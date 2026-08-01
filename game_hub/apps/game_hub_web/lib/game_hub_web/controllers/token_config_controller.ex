# ==================================
# WIWIGA - Controller Admin Config Jetons
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.TokenConfigController
# Description: Administration configuration jetons et promos

defmodule GameHubWeb.TokenConfigController do
  @moduledoc """
  Controller admin pour la configuration des jetons.
  
  ## Endpoints Admin
    GET  /api/admin/config/tokens  - Configuration jetons
    PUT  /api/admin/config/tokens  - MAJ config jetons
    GET  /api/admin/promos         - Lister promos
    POST /api/admin/promos         - Créer promo
    PUT  /api/admin/promos/:id     - MAJ promo
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.Tokens.{TokenConfig, PromoToken}
  alias GameHub.{AuditLog, Repo}
  alias GameHubWeb.AuthPlug
  
  # ========================================
  # CONFIG JETONS
  # ========================================
  
  @doc """
  GET /api/admin/config/tokens
  """
  def get_config(conn, _params) do
    config = TokenConfig.get_config()
    
    conn |> put_status(200) |> json(%{
      success: true,
      data: %{
        token_config: config,
        tokens_to_monetary_100: TokenConfig.tokens_to_monetary(100, config),
        monetary_1000_to_tokens: TokenConfig.monetary_to_tokens(1000, config)
      }
    })
  end
  
  @doc """
  PUT /api/admin/config/tokens
  """
  def update_config(conn, %{"token_config" => attrs}) do
    user_id = AuthPlug.get_current_user_id(conn)
    
    case TokenConfig.update_config(Map.put(attrs, "updated_by_id", user_id)) do
      {:ok, config} ->
        AuditLog.log("update_token_config", user_id, "tokens", "config", attrs)
        
        conn |> put_status(200) |> json(%{
          success: true,
          message: "Configuration jetons mise à jour",
          data: %{token_config: config}
        })
      
      {:error, changeset} ->
        conn |> put_status(422) |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  def update_config(conn, _params) do
    conn |> put_status(400) |> json(%{
      success: false,
      message: "Body requis: {\"token_config\": {...}}"
    })
  end
  
  # ========================================
  # PROMOTIONS
  # ========================================
  
  @doc """
  GET /api/admin/promos
  """
  def list_promos(conn, _params) do
    import Ecto.Query
    
    promos = Repo.all(from p in PromoToken, order_by: [desc: p.inserted_at])
    
    conn |> put_status(200) |> json(%{
      success: true,
      data: %{promos: promos}
    })
  end
  
  @doc """
  POST /api/admin/promos
  """
  def create_promo(conn, %{"promo" => attrs}) do
    user_id = AuthPlug.get_current_user_id(conn)
    
    case PromoToken.create_promo(Map.put(attrs, "created_by_id", user_id)) do
      {:ok, promo} ->
        AuditLog.log("create_promo", user_id, "tokens", "promo_#{promo.id}", %{name: promo.name})
        
        conn |> put_status(201) |> json(%{
          success: true,
          message: "Promotion créée",
          data: %{promo: promo}
        })
      
      {:error, changeset} ->
        conn |> put_status(422) |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  @doc """
  PUT /api/admin/promos/:id
  """
  def update_promo(conn, %{"id" => id} = params) do
    user_id = AuthPlug.get_current_user_id(conn)
    attrs = Map.get(params, "promo", %{})
    
    case Repo.get(PromoToken, String.to_integer(id)) do
      nil ->
        conn |> put_status(404) |> json(%{success: false, message: "Promotion non trouvée"})
      
      promo ->
        case PromoToken.update_promo(promo, attrs) do
          {:ok, updated} ->
            AuditLog.log("update_promo", user_id, "tokens", "promo_#{updated.id}")
            
            conn |> put_status(200) |> json(%{
              success: true,
              message: "Promotion mise à jour",
              data: %{promo: updated}
            })
          
          {:error, changeset} ->
            conn |> put_status(422) |> json(%{
              success: false,
              message: "Erreur de validation",
              errors: translate_errors(changeset)
            })
        end
    end
  end
  
  # === Privé ===
  
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
