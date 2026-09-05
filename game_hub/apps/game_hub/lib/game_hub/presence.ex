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
  @global_topic "online:lobby"
  # Per-game topics: "online:game:{game_type}"

  def global_topic, do: @global_topic
  def game_topic(game_type), do: "online:game:#{game_type}"

  @doc """
  Marque un utilisateur comme en ligne (global + legacy user_presence).
  """
  def track_user(user_id, meta \\ %{}) do
    base = %{
      status: "online",
      joined_at: System.system_time(:millisecond)
    }
    meta = Map.merge(base, meta)
    # Legacy
    track(self(), @topic, to_string(user_id), meta)
    # Global online
    track(self(), @global_topic, to_string(user_id), meta)
  end

  def track_game(user_id, game_type, meta \\ %{}) do
    base = %{status: "online", game_type: game_type, joined_at: System.system_time(:millisecond)}
    track(self(), game_topic(game_type), to_string(user_id), Map.merge(base, meta))
  end

  @doc """
  Marque un utilisateur comme déconnecté.
  """
  def untrack_user(user_id) do
    untrack(self(), @topic, to_string(user_id))
    untrack(self(), @global_topic, to_string(user_id))
  end

  def untrack_game(user_id, game_type) do
    untrack(self(), game_topic(game_type), to_string(user_id))
  end

  def untrack_all(user_id) do
    uid = to_string(user_id)
    # Best effort: untrack from all known topics (global + user_presence + all game types)
    untrack(self(), @topic, uid)
    untrack(self(), @global_topic, uid)
    # Game topics will auto-clean on process exit, but try to untrack common ones
    for gt <- ~w(dice ludo card) do
      try do untrack(self(), game_topic(gt), uid) rescue _ -> :ok end
    end
  end

  @doc """
  Vérifie si un utilisateur est en ligne.
  Résilient si le tracker ETS n'est pas encore démarré.
  """
  def online?(user_id) do
    user_id_str = to_string(user_id)
    try do
      case list(@topic) do
        %{^user_id_str => _} -> true
        _ -> false
      end
    rescue
      _ -> false
    catch
      _, _ -> false
    end
  end

  @doc """
  Récupère la liste des utilisateurs en ligne.
  """
  def list_online_users do
    try do
      list(@topic) |> Map.keys()
    rescue
      _ -> []
    catch
      _, _ -> []
    end
  end

  @doc """
  Retourne un MapSet des IDs en ligne (efficace pour batch).
  """
  def online_ids_set do
    try do
      list(@topic)
      |> Map.keys()
      |> MapSet.new()
    rescue
      _ -> MapSet.new()
    catch
      _, _ -> MapSet.new()
    end
  end

  def count_online(topic \\ @global_topic) do
    try do
      list(topic) |> map_size()
    rescue
      _ -> 0
    catch
      _, _ -> 0
    end
  end

  def count_game_online(game_type) do
    count_online(game_topic(game_type))
  end

  # Enrichissement présence (évite N+1)
  def fetch(_topic, presences) do
    for {key, %{metas: metas}} <- presences, into: %{} do
      {key, %{metas: metas, user: %{id: key}}}
    end
  end

  def init(_opts), do: {:ok, %{}}

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{id: user_id, presence: presence, metas: Map.get(presences, user_id, %{})}
      Phoenix.PubSub.local_broadcast(GameHub.PubSub, "proxy:#{topic}", {__MODULE__, {:join, user_data}})
    end
    for {user_id, presence} <- leaves do
      metas = case Map.fetch(presences, user_id) do {:ok, v} -> v; :error -> [] end
      user_data = %{id: user_id, presence: presence, metas: metas}
      Phoenix.PubSub.local_broadcast(GameHub.PubSub, "proxy:#{topic}", {__MODULE__, {:leave, user_data}})
    end
    {:ok, state}
  end
end
