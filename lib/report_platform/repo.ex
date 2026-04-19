defmodule ReportPlatform.Repo do
  use Ecto.Repo,
    otp_app: :report_platform,
    adapter: Ecto.Adapters.Postgres
end
