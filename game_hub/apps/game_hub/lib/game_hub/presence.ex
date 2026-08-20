# ============================================================
# Fichier: presence.ex
# Description: Module Phoenix Presence pour le statut en ligne
# ============================================================

defmodule GameHub.Presence do
  @moduledoc """
  Module de présence Phoenix pour le statut en ligne des utilisateurs.
  
  Permet de tracker quels utilisateurs sont connectés en temps réel
  et de broadcaster les changements de présence aux abonnés.
  """
  
  use Phoenix.Presence,
    otp_app: :game_hub,
    pubsub_server: GameHub.PubSub

  @topic "user_presence"

  @doc """
  Marque un utilisateur comme en ligne.
  """
  def track_user(user_id) do
    track(self(), @topic, to_string(user_id), %{
      status: "online",
      joined_at: System.system_time(:millisecond)
    })
  end

  @doc """
  Marque un utilisateur comme déconnecté.
  """
  def untrack_user(user_id) do
    untrack(self(), @topic, to_string(user_id))
  end

  @doc """
  Vérifie si un utilisateur est en ligne.
  """
  def online?(user_id) do
    user_id_str = to_string(user_id)
    case list(@topic) do
      %{^user_id_str => _} -> true
      _ -> false
    end
  end

  @doc """
  Récupère la liste des utilisateurs en ligne.
  """
  def list_online_users do
    list(@topic)
    |> Map.keys()
  end
end
