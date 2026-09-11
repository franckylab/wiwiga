# ==================================
# WIWIGA - Controller Admin Templates Notifications
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AdminNotificationTemplateController

defmodule GameHubWeb.AdminNotificationTemplateController do
  @moduledoc """
  Controller admin CRUD templates + preview.

  ## Endpoints
      GET  /api/admin/notification-templates
      POST /api/admin/notification-templates
      PUT  /api/admin/notification-templates/:id
      POST /api/admin/notification-templates/:id/preview
  """

  use GameHubWeb, :controller

  alias GameHub.Notifications
  alias GameHub.AuditLog

  @doc """
  GET /api/admin/notification-templates
  """
  def index(conn, params) do
    templates = Notifications.list_templates(params)

    conn |> put_status(200) |> json(%{success: true, data: templates})
  end

  @doc """
  POST /api/admin/notification-templates
  """
  def create(conn, params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    params = Map.put(params, "created_by", to_int(admin_id))

    case Notifications.create_template(params) do
      {:ok, template} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_templates", to_string(template.id), %{"action" => "create", "key" => template.key})

        conn |> put_status(201) |> json(%{success: true, data: template, message: "Template créé"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Validation échouée", errors: format_errors(changeset)})
    end
  end

  @doc """
  PUT /api/admin/notification-templates/:id
  """
  def update(conn, %{"id" => id} = params) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)

    case Notifications.update_template(String.to_integer(id), params) do
      {:ok, template} ->
        AuditLog.log("admin_action", to_int(admin_id), "notification_templates", id, %{"action" => "update"})

        conn |> put_status(200) |> json(%{success: true, data: template})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Template non trouvé"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{success: false, message: "Validation échouée", errors: format_errors(changeset)})
    end
  end

  @doc """
  DELETE /api/admin/notification-templates/:id
  """
  def delete(conn, %{"id" => id}) do
    admin_id = GameHubWeb.AuthPlug.get_current_user_id(conn)
    {:ok, count} = Notifications.delete_template(String.to_integer(id))
    AuditLog.log("admin_action", to_int(admin_id), "notification_templates", id, %{"action" => "delete"})

    if count > 0 do
      conn |> put_status(200) |> json(%{success: true, message: "Template supprimé"})
    else
      conn |> put_status(404) |> json(%{success: false, message: "Template non trouvé"})
    end
  end

  @doc """
  GET /api/admin/notification-templates/variables/:key
  Variables requises (union tous canaux) pour une clé d'événement.
  """
  def variables(conn, %{"key" => key}) do
    conn |> put_status(200) |> json(%{success: true, data: %{key: key, variables: Notifications.template_variables(key)}})
  end

  @doc """
  POST /api/admin/notification-templates/preview-body
  Prévisualise un corps non sauvegardé (édition).
  Body: {channel, body_tpl, variables}
  """
  def preview_body(conn, params) do
    channel = Map.get(params, "channel", "in_app")
    body_tpl = Map.get(params, "body_tpl", "")
    variables = Map.get(params, "variables", %{})

    case Notifications.preview_body(channel, body_tpl, variables) do
      {:ok, rendered} ->
        conn |> put_status(200) |> json(%{success: true, data: rendered})

      {:error, {:missing_variables, missing}} ->
        conn |> put_status(422) |> json(%{success: false, message: "Variables manquantes : #{Enum.join(missing, ", ")}"})
    end
  end

  @doc """
  POST /api/admin/notification-templates/:id/preview
  Body: {variables}
  """
  def preview(conn, %{"id" => id} = params) do
    variables = Map.get(params, "variables", %{})

    case Notifications.preview_template(String.to_integer(id), variables) do
      {:ok, rendered} ->
        conn |> put_status(200) |> json(%{success: true, data: rendered})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{success: false, message: "Template non trouvé"})

      {:error, {:missing_variables, missing}} ->
        conn |> put_status(422) |> json(%{success: false, message: "Variables manquantes : #{Enum.join(missing, ", ")}"})
    end
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
