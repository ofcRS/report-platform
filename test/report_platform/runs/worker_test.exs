defmodule ReportPlatform.Runs.WorkerTest do
  # async: false because the test mutates the global :artifact_storage env
  use ReportPlatform.DataCase, async: false

  use Oban.Testing, repo: ReportPlatform.Repo

  alias ReportPlatform.Coins.Coin
  alias ReportPlatform.Runs
  alias ReportPlatform.Runs.Worker

  setup do
    # Seed a couple of coins so TopCoinsSnapshot has something to render.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.each(1..3, fn rank ->
      Repo.insert!(%Coin{
        rank: rank,
        coin_id: "coin_#{rank}",
        symbol: "C#{rank}",
        name: "Coin #{rank}",
        price_usd: Decimal.new("#{rank * 100}"),
        change_24h: Decimal.new("1.23"),
        volume_24h: Decimal.new("#{rank * 1_000_000}"),
        market_cap: Decimal.new("#{rank * 10_000_000}"),
        inserted_at: now,
        updated_at: now
      })
    end)

    tmp =
      Path.join(System.tmp_dir!(), "report_platform_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp)

    original = Application.get_env(:report_platform, :artifact_storage)

    Application.put_env(:report_platform, :artifact_storage,
      adapter: ReportPlatform.Storage.Local,
      root: tmp
    )

    on_exit(fn ->
      if original do
        Application.put_env(:report_platform, :artifact_storage, original)
      end

      File.rm_rf!(tmp)
    end)

    {:ok, tmp: tmp}
  end

  test "runs a report end-to-end and transitions queued -> running -> done", %{tmp: tmp} do
    {:ok, run} = Runs.create("top_coins_snapshot", %{"limit" => "3", "quote_currency" => "USD"})
    assert run.status == :queued

    assert :ok = perform_job(Worker, %{"run_id" => run.id})

    run = Runs.get!(run.id)
    assert run.status == :done
    assert run.artifact_filename =~ ~r/^top_coins_snapshot-#{run.id}-\d+\.xlsx$/
    assert run.artifact_path != nil
    assert String.starts_with?(run.artifact_path, tmp)

    # Artifact is a real XLSX file
    assert File.exists?(run.artifact_path)
    assert <<"PK", _rest::binary>> = File.read!(run.artifact_path)
  end

  test "records :failed status with error text when the report id is unknown" do
    {:ok, run} = Runs.create("nonexistent_report", %{})

    assert {:error, _reason} = perform_job(Worker, %{"run_id" => run.id})

    run = Runs.get!(run.id)
    assert run.status == :failed
    assert run.error != nil
  end
end
