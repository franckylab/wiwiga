# ==================================
# WIWIGA - Migration Admin Reports
# ==================================
# Table: admin_reports

defmodule GameHub.Repo.Migrations.AddAdminReports do
  use Ecto.Migration

  def change do
    create table(:admin_reports) do
      add :name, :string, null: false
      add :type, :string, null: false
      add :parameters, :map, default: %{}
      add :generated_by, :integer
      add :file_path, :string
      add :file_size, :integer, default: 0
      add :status, :string, default: "pending"
      add :error_message, :text
      add :row_count, :integer, default: 0
      timestamps()
    end

    create index(:admin_reports, [:type])
    create index(:admin_reports, [:status])
    create index(:admin_reports, [:inserted_at])
  end
end
