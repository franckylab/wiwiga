# ==================================
# WIWIGA - Friend Controller
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.FriendController
# Description: Endpoints REST pour le système d'amis

defmodule GameHubWeb.FriendController do
  @moduledoc """
  Controller REST pour le système d'amis.

  ## Endpoints
    GET    /api/friends                  - Liste amis
    GET    /api/friends/requests         - Demandes en attente
    POST   /api/friends/request          - Envoyer demande
    POST   /api/friends/request/:id/accept - Accepter
    POST   /api/friends/request/:id/reject - Refuser
    DELETE /api/friends/:id              - Supprimer ami
    POST   /api/friends/:id/block        - Bloquer
    GET    /api/friends/search           - Rechercher joueur
    GET    /api/friends/leaderboard      - Classement amis
    GET    /api/friends/activity         - Feed activité
    POST   /api/friends/:id/add-from-game - Ajouter après partie
  """

  use GameHubWeb, :controller

  alias GameHub.{Friends, Errors}

  @doc """
  GET /api/friends
  """
  def index(conn, _params) do
    user_id = get_current_user_id(conn)
    friends = Friends.list_friends(user_id)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: friends,
      meta: %{
        total: length(friends),
        pending_requests: Friends.count_pending_requests(user_id),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    })
  end

  @doc """
  GET /api/friends/requests
  """
  def pending_requests(conn, _params) do
    user_id = get_current_user_id(conn)
    requests = Friends.list_pending_requests(user_id)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: requests,
      meta: %{total: length(requests), timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  POST /api/friends/request
  Body: %{phone: "+237..."} ou %{username: "..."} ou %{user_id: 123}
  """
  def send_request(conn, params) do
    user_id = get_current_user_id(conn)

    search_params = cond do
      Map.has_key?(params, "phone") -> %{"phone" => params["phone"]}
      Map.has_key?(params, "username") -> %{"username" => params["username"]}
      Map.has_key?(params, "user_id") -> params["user_id"]
      true -> nil
    end

    case search_params do
      nil ->
        conn |> put_status(400) |> json(Errors.error("Paramètre requis: phone, username ou user_id", 400, "VALIDATION_ERROR"))

      search ->
        case Friends.send_friend_request(user_id, search) do
          {:ok, friendship} ->
            conn |> put_status(201) |> json(%{success: true, data: friendship, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})

          {:error, :user_not_found} ->
            conn |> put_status(404) |> json(Errors.error("Utilisateur non trouvé", 404, "USER_NOT_FOUND"))

          {:error, :cannot_add_self} ->
            conn |> put_status(400) |> json(Errors.error("Impossible de s'ajouter soi-même", 400, "CANNOT_ADD_SELF"))

          {:error, :already_friends} ->
            conn |> put_status(409) |> json(Errors.error("Déjà amis", 409, "ALREADY_FRIENDS"))

          {:error, :request_already_pending} ->
            conn |> put_status(409) |> json(Errors.error("Demande déjà en attente", 409, "REQUEST_PENDING"))

          {:error, :user_blocked} ->
            conn |> put_status(403) |> json(Errors.error("Utilisateur bloqué", 403, "USER_BLOCKED"))

          {:error, _} ->
            conn |> put_status(400) |> json(Errors.error("Erreur lors de l'envoi", 400, "REQUEST_ERROR"))
        end
    end
  end

  @doc """
  POST /api/friends/request/:id/accept
  """
  def accept_request(conn, %{"id" => id}) do
    user_id = get_current_user_id(conn)

    case Friends.accept_friend_request(user_id, id) do
      {:ok, friendship} ->
        conn |> put_status(200) |> json(%{success: true, data: friendship, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})

      {:error, :request_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Demande non trouvée", 404, "NOT_FOUND"))

      {:error, :invalid_request} ->
        conn |> put_status(400) |> json(Errors.error("Demande invalide", 400, "INVALID_REQUEST"))
    end
  end

  @doc """
  POST /api/friends/request/:id/reject
  """
  def reject_request(conn, %{"id" => id}) do
    user_id = get_current_user_id(conn)

    case Friends.reject_friend_request(user_id, id) do
      {:ok, _} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "rejected"}})

      {:error, :request_not_found} ->
        conn |> put_status(404) |> json(Errors.error("Demande non trouvée", 404, "NOT_FOUND"))

      {:error, :invalid_request} ->
        conn |> put_status(400) |> json(Errors.error("Demande invalide", 400, "INVALID_REQUEST"))
    end
  end

  @doc """
  DELETE /api/friends/:id
  """
  def remove_friend(conn, %{"id" => id}) do
    user_id = get_current_user_id(conn)

    case Friends.remove_friend(user_id, id) do
      {:ok, _} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "removed"}})

      {:error, :not_friends} ->
        conn |> put_status(404) |> json(Errors.error("Pas amis", 404, "NOT_FRIENDS"))
    end
  end

  @doc """
  POST /api/friends/:id/block
  """
  def block_friend(conn, %{"id" => id}) do
    user_id = get_current_user_id(conn)

    case Friends.block_user(user_id, id) do
      {:ok, _} ->
        conn |> put_status(200) |> json(%{success: true, data: %{status: "blocked"}})

      {:error, _} ->
        conn |> put_status(400) |> json(Errors.error("Erreur lors du blocage", 400, "BLOCK_ERROR"))
    end
  end

  @doc """
  GET /api/friends/search?q=...
  """
  def search(conn, %{"q" => query}) do
    user_id = get_current_user_id(conn)
    results = Friends.search_player(user_id, query)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: results,
      meta: %{total: length(results), timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  def search(conn, _params) do
    conn |> put_status(400) |> json(Errors.error("Paramètre 'q' requis", 400, "VALIDATION_ERROR"))
  end

  @doc """
  GET /api/friends/leaderboard
  """
  def leaderboard(conn, _params) do
    user_id = get_current_user_id(conn)
    leaderboard = Friends.get_friend_leaderboard(user_id)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: leaderboard,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  GET /api/friends/activity
  """
  def activity(conn, _params) do
    user_id = get_current_user_id(conn)
    activities = Friends.get_friend_activity(user_id)

    conn
    |> put_status(200)
    |> json(%{
      success: true,
      data: activities,
      meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
    })
  end

  @doc """
  POST /api/friends/:id/add-from-game
  Ajouter un ami depuis une partie.
  """
  def add_from_game(conn, %{"id" => id}) do
    user_id = get_current_user_id(conn)

    case Friends.add_friend_from_game(user_id, id) do
      {:ok, friendship} ->
        conn |> put_status(201) |> json(%{success: true, data: friendship, meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}})

      {:error, reason} ->
        conn |> put_status(400) |> json(Errors.error("Erreur: #{inspect(reason)}", 400, "ADD_FRIEND_ERROR"))
    end
  end

  # === Helpers ===

  defp get_current_user_id(conn) do
    GameHubWeb.AuthPlug.get_current_user_id(conn)
  end
end
