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
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Creer l'entree de rapport
    result = Repo.insert_all("admin_reports", [
      %{
        name: report_name,
        type: report_type,
        parameters: Map.get(params, "parameters", %{}),
        generated_by: admin_id,
        status: "completed",
        file_path: nil,
        file_size: 0,
        row_count: 0,
        inserted_at: now,
        updated_at: now
      }
    ], returning: true)

    case result do
      {1, [report]} ->
        conn |> put_status(201) |> json(%{report: report, message: "Rapport genere avec succes"})
      _ ->
        conn |> put_status(422) |> json(%{error: "Failed to generate report"})
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
    case conn.assigns[:current_admin] do
      %{id: id} -> id
      _ -> 0
    end
  end
end
