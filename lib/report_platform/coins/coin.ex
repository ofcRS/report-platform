defmodule ReportPlatform.Coins.Coin do
  use Ecto.Schema

  schema "coins_snapshot" do
    field :rank, :integer
    field :coin_id, :string
    field :symbol, :string
    field :name, :string
    field :price_usd, :decimal
    field :change_24h, :decimal
    field :volume_24h, :decimal
    field :market_cap, :decimal

    timestamps(type: :utc_datetime)
  end
end
