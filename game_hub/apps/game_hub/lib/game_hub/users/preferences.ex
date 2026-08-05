# ==================================
# WIWIGA - Module Préférences Utilisateur
# ==================================
# Module: GameHub.Users.Preferences
# Description: Gestion des préférences utilisateur (JSONB)
#              Son, vibration, notifications, langue, thème, taille police

defmodule GameHub.Users.Preferences do
  @moduledoc """
  Gestion des préférences utilisateur.
  
  Les préférences sont stockées en JSONB dans la table users.
  Merge avec des valeurs par défaut pour garantir la complétude.
  """
  
  alias GameHub.{Repo, Users.User}
  
  # Valeurs par défaut
  @defaults %{
    "sound_enabled" => true,
    "vibration_enabled" => true,
    "notifications_enabled" => true,
    "language" => "fr",
    "theme" => "neon",
    "font_size" => "medium"
  }
  
  @allowed_keys Map.keys(@defaults)
  
  @doc """
  Récupère les préférences complètes d'un utilisateur.
  Merge les valeurs stockées avec les défauts.
  """
  def get_preferences(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        stored = user.preferences || %{}
        merged = Map.merge(@defaults, stored)
        {:ok, merged}
    end
  end
  
  @doc """
  Met à jour les préférences (partial update).
  Seules les clés autorisées sont acceptées.
  """
  def update_preferences(user_id, prefs) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :user_not_found}
      
      user ->
        # Filtrer les clés autorisées
        filtered = Map.take(prefs, @allowed_keys)
        
        # Valider les valeurs
        case validate_preferences(filtered) do
          :ok ->
            current = user.preferences || %{}
            merged = Map.merge(current, filtered)
            
            user
            |> User.preferences_changeset(%{preferences: merged})
            |> Repo.update()
            |> case do
              {:ok, updated_user} -> {:ok, Map.merge(@defaults, updated_user.preferences)}
              error -> error
            end
          
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  @doc """
  Retourne les valeurs par défaut.
  """
  def defaults, do: @defaults
  
  @doc """
  Récupère une préférence spécifique.
  """
  def get_preference(user_id, key, default \\ nil) do
    case get_preferences(user_id) do
      {:ok, prefs} -> Map.get(prefs, key, default)
      _ -> default
    end
  end
  
  # --- Validation privée ---
  
  defp validate_preferences(prefs) do
    cond do
      # Validation language
      Map.has_key?(prefs, "language") and prefs["language"] not in ~w(fr en) ->
        {:error, "Langue non supportée. Valeurs acceptées: fr, en"}
      
      # Validation theme
      Map.has_key?(prefs, "theme") and prefs["theme"] not in ~w(neon dark light) ->
        {:error, "Thème non supporté. Valeurs acceptées: neon, dark, light"}
      
      # Validation font_size
      Map.has_key?(prefs, "font_size") and prefs["font_size"] not in ~w(small medium large) ->
        {:error, "Taille de police non supportée. Valeurs acceptées: small, medium, large"}
      
      # Validation booléens
      Map.has_key?(prefs, "sound_enabled") and not is_boolean(prefs["sound_enabled"]) ->
        {:error, "sound_enabled doit être true/false"}
      
      Map.has_key?(prefs, "vibration_enabled") and not is_boolean(prefs["vibration_enabled"]) ->
        {:error, "vibration_enabled doit être true/false"}
      
      Map.has_key?(prefs, "notifications_enabled") and not is_boolean(prefs["notifications_enabled"]) ->
        {:error, "notifications_enabled doit être true/false"}
      
      true ->
        :ok
    end
  end
end
