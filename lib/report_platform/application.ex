defmodule ReportPlatform.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReportPlatformWeb.Telemetry,
      ReportPlatform.Repo,
      {DNSCluster, query: Application.get_env(:report_platform, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ReportPlatform.PubSub},
      {Oban, Application.fetch_env!(:report_platform, Oban)},
      {ChromicPDF, chromic_pdf_opts()},
      ReportPlatformWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ReportPlatform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ReportPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp chromic_pdf_opts do
    base = [
      session_pool: [size: 3, timeout: 10_000],
      no_sandbox: true,
      chrome_args: "--disable-dev-shm-usage --disable-gpu"
    ]

    case System.get_env("CHROME_EXECUTABLE") do
      nil -> base
      "" -> base
      path -> Keyword.put(base, :chrome_executable, path)
    end
  end
end
