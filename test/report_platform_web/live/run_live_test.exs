defmodule ReportPlatformWeb.RunLiveTest do
  use ReportPlatformWeb.ConnCase, async: true
  use Oban.Testing, repo: ReportPlatform.Repo

  import Phoenix.LiveViewTest

  describe "GET /reports/:id" do
    test "renders defaults for a valid report", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports/top_coins_snapshot")

      assert html =~ "Top Coins Snapshot"
      assert html =~ "Number of coins"
      # default limit should be pre-filled
      assert html =~ ~s(value="50")
    end

    test "redirects with flash when the report id is unknown", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: flash}}} =
               live(conn, ~p"/reports/not_a_real_report")

      assert %{"error" => msg} = flash
      assert msg =~ "Unknown report"
    end
  end

  describe "submit" do
    test "rejects invalid params and stays on the page without enqueuing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports/top_coins_snapshot")

      html =
        view
        |> form("#run-form", report_params: %{"limit" => "9999", "quote_currency" => "USD"})
        |> render_submit()

      # Invalid (limit > 500); error rendered and no Oban job enqueued.
      assert html =~ "must be less than or equal to 500" or html =~ "must be less than"
      assert [] = all_enqueued(queue: :reports)
    end

    test "valid submit creates a run, enqueues an Oban job", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports/top_coins_snapshot")

      view
      |> form("#run-form", report_params: %{"limit" => "10", "quote_currency" => "USD"})
      |> render_submit()

      # A Run row should now exist in :queued.
      assert [%ReportPlatform.Runs.Run{id: run_id, status: :queued}] =
               ReportPlatform.Runs.list()

      # Oban should have received exactly one job carrying that run id.
      assert [%Oban.Job{worker: "ReportPlatform.Runs.Worker", args: %{"run_id" => ^run_id}}] =
               all_enqueued(queue: :reports)
    end
  end
end
