# ==================================
# WIWIGA - Admin Configuration Controllers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.API.Admin
# Description: Controllers pour la configuration dynamique

defmodule GameHubWeb.API.Admin.ConfigController do
  @moduledoc """
  Controllers pour la gestion de la configuration dynamique via le dashboard admin.
  
  ## Endpoints
  
  ### Thème UI (Singleton)
  - `GET /api/admin/config/theme` - Lire configuration thème
  - `PUT /api/admin/config/theme` - Modifier configuration thème
  
  ### Features (Singleton)
  - `GET /api/admin/config/features` - Lire configuration features
  - `PUT /api/admin/config/features` - Modifier configuration features
  
  ### Jeux (Par type)
  - `GET /api/admin/config/games` - Lister toutes les configs jeux
  - `GET /api/admin/config/games/:type` - Lire config d'un jeu
  - `PUT /api/admin/config/games/:type` - Modifier config d'un jeu
  
  ### Paiements (Par provider)
  - `GET /api/admin/config/payments` - Lister toutes les configs paiement
  - `GET /api/admin/config/payments/:provider` - Lire config d'un provider
  - `PUT /api/admin/config/payments/:provider` - Modifier config d'un provider
  
  ## Permissions
  - Lecture: Admin, Super Admin
  - Écriture thème/features/jeux: Super Admin, Admin
  - Écriture paiements: Super Admin uniquement
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.{UI, Repo, AuditLog}
  alias GameHubWeb.AuthPlug
  alias UI.{ThemeConfig, FeatureConfig, GameConfig, PaymentConfig}
  alias GameHub.Admin.ConfigChangeLog
  import Ecto.Query
  
  # ========================================
  # THÈME UI
  # ========================================
  
  @doc """
  GET /api/admin/config/theme
  
  Retourne la configuration actuelle du thème UI.
  """
  def get_theme_config(conn, _params) do
    config = ThemeConfig.get_config()
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        theme_config: config,
        last_updated_by: load_updated_by_name(config.updated_by_id)
      }
    })
  end
  
  @doc """
  PUT /api/admin/config/theme
  
  Met à jour la configuration du thème UI.
  
  Body:
  ```json
  {
    "primary_color": "#2DD4BF",
    "secondary_color": "#F59E0B",
    "border_radius": 12.0,
    "glow_intensity": 0.5
  }
  ```
  """
  def update_theme_config(conn, %{"theme_config" => attrs}) do
    user = AuthPlug.get_current_user(conn)
    
    case ThemeConfig.update_config(Map.put(attrs, "updated_by_id", user.id)) do
      {:ok, config} ->
        AuditLog.log_admin_action(user.id, "update_theme_config", attrs)
        log_config_change(user.id, "theme", config.id, nil, attrs, "Updated theme configuration")
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          message: "Configuration du thème mise à jour avec succès",
          data: %{
            theme_config: config,
            websocket_broadcast: "theme:update"
          }
        })
      
      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  def update_theme_config(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{
      success: false,
      message: "Body requis: {\"theme_config\": {...}}"
    })
  end
  
  # ========================================
  # FEATURES
  # ========================================
  
  @doc """
  GET /api/admin/config/features
  
  Retourne la configuration actuelle des features.
  """
  def get_feature_config(conn, _params) do
    config = FeatureConfig.get_config()
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        feature_config: config,
        last_updated_by: load_updated_by_name(config.updated_by_id)
      }
    })
  end
  
  @doc """
  PUT /api/admin/config/features
  
  Met à jour la configuration des features.
  
  Body:
  ```json
  {
    "maintenance_mode": false,
    "min_deposit_amount": 500,
    "max_deposit_amount": 1000000,
    "kyc_required_threshold": 100000
  }
  ```
  """
  def update_feature_config(conn, %{"feature_config" => attrs}) do
    user = AuthPlug.get_current_user(conn)
    
    case FeatureConfig.update_config(Map.put(attrs, "updated_by_id", user.id)) do
      {:ok, config} ->
        AuditLog.log_admin_action(user.id, "update_feature_config", attrs)
        log_config_change(user.id, "features", config.id, nil, attrs, "Updated feature configuration")
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          message: "Configuration des features mise à jour avec succès",
          data: %{
            feature_config: config,
            websocket_broadcast: "feature:update"
          }
        })
      
      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  def update_feature_config(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{
      success: false,
      message: "Body requis: {\"feature_config\": {...}}"
    })
  end
  
  # ========================================
  # JEUX
  # ========================================
  
  @doc """
  GET /api/admin/config/games
  
  Liste toutes les configurations de jeux.
  """
  def list_game_configs(conn, _params) do
    configs = GameConfig.list_configs()
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        game_configs: configs,
        total: length(configs)
      }
    })
  end
  
  @doc """
  GET /api/admin/config/games/:type
  
  Retourne la configuration d'un jeu spécifique.
  """
  def get_game_config(conn, %{"type" => game_type}) do
    case GameConfig.get_config(game_type) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{
          success: false,
          message: "Configuration non trouvée pour le jeu: #{game_type}"
        })
      
      config ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            game_config: config,
            last_updated_by: load_updated_by_name(config.updated_by_id)
          }
        })
    end
  end
  
  @doc """
  PUT /api/admin/config/games/:type
  
  Crée ou met à jour la configuration d'un jeu.
  
  Body:
  ```json
  {
    "enabled": true,
    "min_bet": 100,
    "max_bet": 500000,
    "commission_rate": 0.05,
    "game_settings": {
      "dice_count": 1,
      "animation_enabled": true
    }
  }
  ```
  """
  def update_game_config(conn, %{"type" => game_type, "game_config" => attrs}) do
    user = AuthPlug.get_current_user(conn)
    
    case GameConfig.create_or_update(game_type, Map.put(attrs, "updated_by_id", user.id)) do
      {:ok, config} ->
        AuditLog.log_admin_action(user.id, "update_game_config", %{game_type: game_type} |> Map.merge(attrs))
        log_config_change(user.id, "games", config.id, nil, Map.put(attrs, "type", game_type), "Updated game config: #{game_type}")
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          message: "Configuration du jeu #{game_type} mise à jour avec succès",
          data: %{
            game_config: config,
            websocket_broadcast: "game_config:update:#{game_type}"
          }
        })
      
      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  def update_game_config(conn, %{"type" => _game_type}) do
    conn
    |> put_status(400)
    |> json(%{
      success: false,
      message: "Body requis: {\"game_config\": {...}}"
    })
  end
  
  # ========================================
  # PAIEMENTS
  # ========================================
  
  @doc """
  GET /api/admin/config/payments
  
  Liste toutes les configurations de paiement.
  """
  def list_payment_configs(conn, _params) do
    configs = PaymentConfig.list_enabled_configs()
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        payment_configs: configs,
        total: length(configs)
      }
    })
  end
  
  @doc """
  GET /api/admin/config/payments/:provider
  
  Retourne la configuration d'un provider de paiement.
  """
  def get_payment_config(conn, %{"provider" => provider}) do
    case PaymentConfig.get_config(provider) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{
          success: false,
          message: "Configuration non trouvée pour le provider: #{provider}"
        })
      
      config ->
        # Exclure les secrets de la réponse
        safe_config = Map.drop(Map.from_struct(config), [:api_key, :api_secret])
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            payment_config: safe_config,
            has_api_credentials: !is_nil(config.api_key)
          }
        })
    end
  end
  
  @doc """
  PUT /api/admin/config/payments/:provider
  
  Crée ou met à jour la configuration d'un provider de paiement.
  
  Body:
  ```json
  {
    "enabled": true,
    "min_amount": 500,
    "max_amount": 1000000,
    "api_key": "your-api-key",
    "api_secret": "your-api-secret",
    "provider_settings": {
      "timeout_ms": 30000
    }
  }
  ```
  """
  def update_payment_config(conn, %{"provider" => provider, "payment_config" => attrs}) do
    user = AuthPlug.get_current_user(conn)
    
    case PaymentConfig.create_or_update(provider, Map.put(attrs, "updated_by_id", user.id)) do
      {:ok, config} ->
        AuditLog.log_admin_action(user.id, "update_payment_config", %{
          provider: provider,
          action: "configuration_updated"
        })
        log_config_change(user.id, "payments", config.id, nil, Map.put(attrs, "provider", provider), "Updated payment config: #{provider}")
        
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          message: "Configuration du provider #{provider} mise à jour avec succès",
          data: %{
            payment_config: Map.drop(Map.from_struct(config), [:api_key, :api_secret]),
            websocket_broadcast: "payment_config:update:#{provider}"
          }
        })
      
      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{
          success: false,
          message: "Erreur de validation",
          errors: translate_errors(changeset)
        })
    end
  end
  
  def update_payment_config(conn, %{"provider" => _provider}) do
    conn
    |> put_status(400)
    |> json(%{
      success: false,
      message: "Body requis: {\"payment_config\": {...}}"
    })
  end
  
  # ========================================
  # HISTORIQUE & ROLLBACK
  # ========================================

  @doc """
  GET /api/admin/config/history
  Retourne l'historique des changements de configuration.
  
  Params:
    - type: type de config (theme, features, games, payments)
    - limit: nombre max d'entrées (défaut 50)
  """
  def config_history(conn, params) do
    limit = min(Map.get(params, "limit", "50") |> String.to_integer(), 200)
    
    query = from cl in ConfigChangeLog,
      order_by: [desc: cl.inserted_at],
      limit: ^limit,
      select: %{
        id: cl.id,
        config_type: cl.config_type,
        config_id: cl.config_id,
        changed_by: cl.changed_by,
        old_values: cl.old_values,
        new_values: cl.new_values,
        change_summary: cl.change_summary,
        inserted_at: cl.inserted_at
      }
    
    query = case params["type"] do
      nil -> query
      type -> from cl in query, where: cl.config_type == ^type
    end
    
    logs = Repo.all(query)
    
    # Enrichir avec le nom de l'auteur
    enriched_logs = Enum.map(logs, fn log ->
      Map.put(log, :changed_by_name, load_updated_by_name(log.changed_by))
    end)
    
    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: %{
        history: enriched_logs,
        total: length(enriched_logs)
      }
    })
  end

  @doc """
  POST /api/admin/config/rollback/:log_id
  Restaurer une configuration précédente.
  
  Restaure les old_values du log sélectionné dans la config correspondante.
  """
  def rollback_config(conn, %{"log_id" => log_id_str}) do
    user = AuthPlug.get_current_user(conn)
    
    case Integer.parse(log_id_str) do
      :error ->
        conn |> put_status(400) |> json(%{success: false, message: "ID invalide"})
      
      {log_id, _} ->
        case Repo.get(ConfigChangeLog, log_id) do
          nil ->
            conn |> put_status(404) |> json(%{success: false, message: "Historique non trouvé"})
          
          log ->
            result = perform_rollback(log, user)
            
            case result do
              {:ok, _config} ->
                AuditLog.log_admin_action(user.id, "rollback_config", %{
                  log_id: log_id,
                  config_type: log.config_type,
                  summary: log.change_summary
                })
                
                conn
                |> put_status(200)
                |> json(%{
                  success: true,
                  message: "Configuration restaurée avec succès (type: #{log.config_type})",
                  data: %{
                    config_type: log.config_type,
                    restored_from_log: log_id,
                    rolled_back_by: user.id
                  }
                })
              
              {:error, reason} ->
                conn
                |> put_status(422)
                |> json(%{success: false, message: "Erreur lors du rollback: #{inspect(reason)}"})
            end
        end
    end
  end

  defp perform_rollback(log, user) do
    case log.config_type do
      "theme" ->
        ThemeConfig.update_config(Map.put(log.old_values, "updated_by_id", user.id))
      
      "features" ->
        FeatureConfig.update_config(Map.put(log.old_values, "updated_by_id", user.id))
      
      "games" ->
        if log.config_id do
          game_type = Map.get(log.old_values, "type", "dice")
          GameConfig.create_or_update(game_type, Map.put(log.old_values, "updated_by_id", user.id))
        else
          {:error, :missing_config_id}
        end
      
      "payments" ->
        if log.config_id do
          provider = Map.get(log.old_values, "provider", "campay")
          PaymentConfig.create_or_update(provider, Map.put(log.old_values, "updated_by_id", user.id))
        else
          {:error, :missing_config_id}
        end
      
      _ ->
        {:error, :unknown_config_type}
    end
  end

  # ========================================
  # HELPERS PRIVÉS
  # ========================================
  
  defp load_updated_by_name(nil), do: nil
  
  defp load_updated_by_name(user_id) do
    case Repo.get(GameHub.Users.User, user_id) do
      nil -> nil
      user -> user.name || user.email
    end
  end
  
  @doc """
  Log un changement de configuration dans l'historique.
  Appelé par les fonctions update après chaque modification réussie.
  """
  def log_config_change(user_id, config_type, config_id, old_values, new_values, summary \\ nil) do
    %ConfigChangeLog{}
    |> ConfigChangeLog.changeset(%{
      config_type: config_type,
      config_id: config_id,
      changed_by: user_id,
      old_values: old_values || %{},
      new_values: new_values,
      change_summary: summary || "Updated #{config_type} configuration"
    })
    |> Repo.insert()
  end
  
  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
