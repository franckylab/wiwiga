# ==================================
# WIWIGA - Controller Admin Player Progression
# ==================================
# Module: GameHubWeb.AdminPlayerProgressionController
# Description: Endpoints API pour configuration progression joueur

defmodule GameHubWeb.AdminPlayerProgressionController do
  use GameHubWeb, :controller

  alias GameHub.Admin.PlayerProgression

  @doc """
  GET /api/admin/player-progression/levels
  Liste toutes les configurations de niveaux.
  """
  def levels(conn, _params) do
    levels = PlayerProgression.list_level_configs()
    json(conn, %{data: levels})
  end

  @doc """
  POST /api/admin/player-progression/levels
  Crée une nouvelle configuration de niveau.
  """
  def create_level(conn, params) do
    admin_id = conn.assigns[:current_user_id] || conn.assigns[:current_admin_id] || conn.private[:current_user_id] || 0
    admin_id = if is_binary(admin_id) do case Integer.parse(admin_id) do {n,_} -> n; :error -> 0 end else admin_id end

    case PlayerProgression.create_level_config(params, admin_id) do
      {:ok, config} ->
        conn
        |> put_status(:created)
        |> json(%{data: config, message: "Niveau créé"})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  DELETE /api/admin/player-progression/levels/:tier
  Supprime une configuration de niveau.
  """
  def delete_level(conn, %{"tier" => tier}) do
    admin_id = conn.assigns[:current_user_id] || conn.assigns[:current_admin_id] || conn.private[:current_user_id] || 0
    admin_id = if is_binary(admin_id) do case Integer.parse(admin_id) do {n,_} -> n; :error -> 0 end else admin_id end

    case PlayerProgression.delete_level_config(tier, admin_id) do
      {:ok, _} ->
        json(conn, %{message: "Niveau supprimé"})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Niveau non trouvé"})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  PUT /api/admin/player-progression/levels/:tier
  Met à jour la configuration d'un niveau.
  """
  def update_level(conn, %{"tier" => tier} = params) do
    admin_id = conn.assigns[:current_user_id] || conn.assigns[:current_admin_id] || conn.private[:current_user_id] || 0
    admin_id = if is_binary(admin_id) do case Integer.parse(admin_id) do {n,_} -> n; :error -> 0 end else admin_id end
    attrs = Map.drop(params, ["tier"])

    case PlayerProgression.update_level_config(tier, attrs, admin_id) do
      {:ok, config} ->
        json(conn, %{data: config, message: "Niveau mis à jour"})
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Niveau non trouvé"})
      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{error: to_string(reason)})
    end
  end

  @doc """
  GET /api/admin/player-progression/calculate/:xp
  Calcule le tier pour un montant d'XP donné (utilitaire admin).
  """
  def calculate_tier(conn, %{"xp" => xp_str}) do
    case Integer.parse(xp_str) do
      {xp, _} ->
        tier = PlayerProgression.calculate_tier(xp)
        json(conn, %{data: tier})
      :error ->
        conn |> put_status(:bad_request) |> json(%{error: "XP invalide"})
    end
  end
end
