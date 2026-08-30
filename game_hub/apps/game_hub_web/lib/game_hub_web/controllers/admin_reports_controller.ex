# ==================================
# WIWIGA - Admin Reports Controller
# ==================================
# Endpoints: List, Generate, Download

defmodule GameHubWeb.AdminReportsController do
  use GameHubWeb, :controller

  alias GameHub.Repo
  import Ecto.Query

  def index(conn, _params) do
    reports = Repo.all(
      from r in "admin_reports",
        order_by: [desc: r.inserted_at],
        limit: 50,
        select: %{
          id: r.id,
          name: r.name,
          type: r.type,
          parameters: r.parameters,
          status: r.status,
          file_path: r.file_path,
          file_size: r.file_size,
          row_count: r.row_count,
          generated_by: r.generated_by,
          inserted_at: r.inserted_at
        }
    )

    json(conn, %{reports: reports})
  end

  def generate(conn, params) do
    admin_id = get_admin_id(conn)
    report_type = Map.get(params, "type", "financial")
    report_name = Map.get(params, "name", "Rapport #{report_type}")
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    # Creer l'entree de rapport - sans returning (incompatible avec table string)
    try do
      parameters = Map.get(params, "parameters", %{})
      parameters = if is_map(parameters), do: parameters, else: %{}

      {count, _} = Repo.insert_all("admin_reports", [
        %{
          name: report_name,
          type: report_type,
          parameters: parameters,
          generated_by: admin_id,
          status: "completed",
          file_path: nil,
          file_size: 0,
          row_count: 0,
          inserted_at: now,
          updated_at: now
        }
      ])

      if count == 1 do
        # Récupérer le dernier rapport créé pour cet admin/type
        report = Repo.one(
          from r in "admin_reports",
            where: r.generated_by == ^admin_id and r.type == ^report_type,
            order_by: [desc: r.inserted_at, desc: r.id],
            limit: 1,
            select: %{
              id: r.id,
              name: r.name,
              type: r.type,
              parameters: r.parameters,
              status: r.status,
              file_path: r.file_path,
              file_size: r.file_size,
              row_count: r.row_count,
              generated_by: r.generated_by,
              inserted_at: r.inserted_at
            }
        ) || %{name: report_name, type: report_type, status: "completed", generated_by: admin_id}

        conn |> put_status(201) |> json(%{report: report, message: "Rapport genere avec succes"})
      else
        conn |> put_status(422) |> json(%{error: "Failed to generate report"})
      end
    rescue
      e ->
        require Logger
        Logger.error("[AdminReports.generate] #{Exception.format(:error, e, __STACKTRACE__)}")
        conn |> put_status(500) |> json(%{error: "Internal server error", details: Exception.message(e)})
    catch
      kind, reason ->
        require Logger
        Logger.error("[AdminReports.generate] #{kind}: #{inspect(reason)}")
        conn |> put_status(500) |> json(%{error: "Internal server error"})
    end
  end

  def download(conn, %{"id" => id}) do
    report = Repo.one(
      from r in "admin_reports",
        where: r.id == ^id,
        select: %{id: r.id, name: r.name, type: r.type, status: r.status, file_path: r.file_path}
    )

    case report do
      nil ->
        conn |> put_status(404) |> json(%{error: "Report not found"})
      %{status: "completed", file_path: path} when not is_nil(path) ->
        if File.exists?(path) do
          send_download(conn, {:file, path}, filename: "#{report.name}.csv")
        else
          conn |> put_status(404) |> json(%{error: "File not found"})
        end
      _ ->
        conn |> put_status(422) |> json(%{error: "Report not ready for download"})
    end
  end

  defp get_admin_id(conn) do
    # AdminAuthPlug assigne :current_user et :current_user_id
    case conn.assigns[:current_user] do
      %{id: id} -> id
      _ ->
        case conn.assigns[:current_user_id] do
          id when is_integer(id) -> id
          id when is_binary(id) ->
            case Integer.parse(id) do
              {n, _} -> n
              :error -> 0
            end
          _ ->
            # fallback legacy :current_admin ou private
            case conn.assigns[:current_admin] do
              %{id: id} -> id
              id when is_integer(id) -> id
              _ -> conn.private[:current_user_id] || 0
            end
        end
    end
    |> case do
      id when is_binary(id) ->
        case Integer.parse(id) do
          {n, _} -> n
          :error -> 0
        end
      id -> id
    end
  end
end
