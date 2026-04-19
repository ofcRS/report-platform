defmodule ReportPlatform.Repo.Migrations.CreateReportRuns do
  use Ecto.Migration

  def change do
    create table(:report_runs) do
      add :report_id, :string, null: false
      add :params, :map, null: false, default: %{}
      add :status, :string, null: false, default: "queued"
      add :artifact_path, :string
      add :artifact_filename, :string
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:report_runs, [:report_id])
    create index(:report_runs, [:status])
    create index(:report_runs, [:inserted_at])
  end
end
