# ==================================
# WIWIGA - Controller Admin CRM
# ==================================
# Module: GameHubWeb.AdminCRMController
# Description: Endpoints CRM joueurs - segments, VIP, notes, risques

defmodule GameHubWeb.AdminCRMController do
  @moduledoc """
  Controller pour le CRM admin.
  
  ## Endpoints
    GET  /api/admin/crm/segments           - Liste des segments
    GET  /api/admin/crm/players/:id/summary - Résumé joueur
    POST /api/admin/crm/players/:id/notes   - Ajouter note
    GET  /api/admin/crm/players/:id/notes   - Notes joueur
    GET  /api/admin/crm/vip                 - Joueurs VIP
    PUT  /api/admin/crm/players/:id/vip-tier - Set VIP tier
    GET  /api/admin/crm/at-risk             - Joueurs à risque
  """

  use GameHubWeb, :controller

  alias GameHub.Admin.CRM

  @doc """
  GET /api/admin/crm/segments
  Liste des segments joueurs.
  """
  def segments(conn, _params) do
    segments = CRM.get_player_segments()

    conn
    |> put_status(200)
    |> json(%{success: true, data: segments})
  end

  @doc """
  GET /api/admin/crm/players/:id/summary
  Résumé complet d'un joueur.
  """
  def player_summary(conn, %{"id" => id}) do
    user_id = String.to_integer(id)

    case CRM.get_player_summary(user_id) do
      {:ok, summary} ->
        conn
        |> put_status(200)
        |> json(%{success: true, data: summary})

      {:error, :user_not_found} ->
        conn
        |> put_status(404)
        |> json(%{success: false, error: %{code: "NOT_FOUND", message: "Joueur non trouvé"}})
    end
  end

  @doc """
  POST /api/admin/crm/players/:id/notes
  Ajouter une note sur un joueur.
  """
  def add_note(conn, %{"id" => id} = params) do
    user_id = String.to_integer(id)
    admin_id = conn.assigns[:current_user_id]
    note = params["note"]
    category = params["category"] || "general"

    if is_nil(note) or String.trim(note) == "" do
      conn
      |> put_status(400)
      |> json(%{success: false, error: %{code: "VALIDATION_ERROR", message: "Note requise"}})
    else
      case CRM.add_note(user_id, admin_id, note, category) do
        {:ok, entry} ->
          conn
          |> put_status(201)
          |> json(%{success: true, data: entry})

        {:error, reason} ->
          conn
          |> put_status(500)
          |> json(%{success: false, error: %{code: "ERROR", message: to_string(reason)}})
      end
    end
  end

  @doc """
  GET /api/admin/crm/players/:id/notes
  Liste des notes d'un joueur.
  """
  def list_notes(conn, %{"id" => id} = params) do
    user_id = String.to_integer(id)
    page = Map.get(params, "page", "1") |> String.to_integer()
    limit = Map.get(params, "limit", "20") |> String.to_integer() |> min(100)

    notes = CRM.list_notes(user_id, page, limit)

    conn
    |> put_status(200)
    |> json(%{success: true, data: notes})
  end

  @doc """
  GET /api/admin/crm/vip
  Joueurs VIP (top par volume).
  """
  def vip_players(conn, params) do
    limit = Map.get(params, "limit", "50") |> String.to_integer() |> min(200)

    players = CRM.get_vip_players(limit)

    conn
    |> put_status(200)
    |> json(%{success: true, data: players})
  end

  @doc """
  PUT /api/admin/crm/players/:id/vip-tier
  Assigner un tier VIP.
  """
  def set_vip_tier(conn, %{"id" => id} = params) do
    user_id = String.to_integer(id)
    admin_id = conn.assigns[:current_user_id]
    tier = params["tier"]

    valid_tiers = ~w(bronze silver gold platinum)

    cond do
      is_nil(tier) ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: %{code: "VALIDATION_ERROR", message: "Tier requis"}})

      tier not in valid_tiers ->
        conn
        |> put_status(400)
        |> json(%{success: false, error: %{code: "INVALID_TIER", message: "Tiers valides: #{Enum.join(valid_tiers, ", ")}"}})

      true ->
        case CRM.set_vip_tier(user_id, tier, admin_id) do
          {:ok, entry} ->
            conn
            |> put_status(200)
            |> json(%{success: true, data: entry})

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{success: false, error: %{code: "ERROR", message: to_string(reason)}})
        end
    end
  end

  @doc """
  GET /api/admin/crm/at-risk
  Joueurs à risque.
  """
  def at_risk_players(conn, _params) do
    players = CRM.get_at_risk_players()

    conn
    |> put_status(200)
    |> json(%{success: true, data: players})
  end
end
