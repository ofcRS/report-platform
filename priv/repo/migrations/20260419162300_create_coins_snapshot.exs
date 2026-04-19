defmodule ReportPlatform.Repo.Migrations.CreateCoinsSnapshot do
  use Ecto.Migration

  def change do
    create table(:coins_snapshot) do
      add :rank, :integer, null: false
      add :coin_id, :string, null: false
      add :symbol, :string, null: false
      add :name, :string, null: false
      add :price_usd, :decimal, precision: 20, scale: 8, null: false
      add :change_24h, :decimal, precision: 10, scale: 4, null: false
      add :volume_24h, :decimal, precision: 20, scale: 2, null: false
      add :market_cap, :decimal, precision: 20, scale: 2, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:coins_snapshot, [:coin_id])
    create unique_index(:coins_snapshot, [:rank])
  end
end
