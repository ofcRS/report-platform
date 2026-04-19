defmodule ReportPlatform.Runs.Run do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:queued, :running, :done, :failed]

  schema "report_runs" do
    field :report_id, :string
    field :params, :map, default: %{}
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :artifact_path, :string
    field :artifact_filename, :string
    field :error, :string

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @required ~w(report_id params status)a
  @optional ~w(artifact_path artifact_filename error)a

  def changeset(run, attrs) do
    run
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:status, @statuses)
  end
end
