alias ReportPlatform.Coins.Coin
alias ReportPlatform.Repo

:rand.seed(:exsss, {1, 2, 3})

coins = [
  {"bitcoin", "BTC", "Bitcoin", 65_000, 1_200_000_000_000},
  {"ethereum", "ETH", "Ethereum", 3_200, 380_000_000_000},
  {"tether", "USDT", "Tether", 1.0, 110_000_000_000},
  {"binancecoin", "BNB", "BNB", 580, 85_000_000_000},
  {"solana", "SOL", "Solana", 145, 65_000_000_000},
  {"ripple", "XRP", "XRP", 0.52, 29_000_000_000},
  {"usd-coin", "USDC", "USD Coin", 1.0, 33_000_000_000},
  {"cardano", "ADA", "Cardano", 0.44, 15_500_000_000},
  {"dogecoin", "DOGE", "Dogecoin", 0.16, 22_500_000_000},
  {"the-open-network", "TON", "Toncoin", 7.2, 25_000_000_000},
  {"avalanche-2", "AVAX", "Avalanche", 35, 13_500_000_000},
  {"shiba-inu", "SHIB", "Shiba Inu", 0.000025, 14_500_000_000},
  {"tron", "TRX", "TRON", 0.12, 10_800_000_000},
  {"polkadot", "DOT", "Polkadot", 7.1, 9_600_000_000},
  {"chainlink", "LINK", "Chainlink", 17, 9_900_000_000},
  {"matic-network", "MATIC", "Polygon", 0.72, 7_100_000_000},
  {"bitcoin-cash", "BCH", "Bitcoin Cash", 475, 9_300_000_000},
  {"litecoin", "LTC", "Litecoin", 82, 6_100_000_000},
  {"near", "NEAR", "NEAR Protocol", 6.4, 6_800_000_000},
  {"dai", "DAI", "Dai", 1.0, 5_200_000_000},
  {"internet-computer", "ICP", "Internet Computer", 12, 5_500_000_000},
  {"uniswap", "UNI", "Uniswap", 10, 5_900_000_000},
  {"stellar", "XLM", "Stellar", 0.11, 3_200_000_000},
  {"ethereum-classic", "ETC", "Ethereum Classic", 27, 3_900_000_000},
  {"kaspa", "KAS", "Kaspa", 0.17, 4_000_000_000},
  {"monero", "XMR", "Monero", 165, 3_000_000_000},
  {"cosmos", "ATOM", "Cosmos Hub", 9.4, 3_500_000_000},
  {"filecoin", "FIL", "Filecoin", 5.5, 3_100_000_000},
  {"aptos", "APT", "Aptos", 7.8, 3_400_000_000},
  {"crypto-com-chain", "CRO", "Cronos", 0.092, 2_400_000_000},
  {"optimism", "OP", "Optimism", 2.3, 2_400_000_000},
  {"okb", "OKB", "OKB", 48, 2_800_000_000},
  {"hedera-hashgraph", "HBAR", "Hedera", 0.073, 2_500_000_000},
  {"arbitrum", "ARB", "Arbitrum", 1.05, 2_700_000_000},
  {"vechain", "VET", "VeChain", 0.031, 2_200_000_000},
  {"mantle", "MNT", "Mantle", 0.73, 2_400_000_000},
  {"maker", "MKR", "Maker", 2_800, 2_500_000_000},
  {"sui", "SUI", "Sui", 1.1, 3_100_000_000},
  {"render-token", "RNDR", "Render", 7.4, 2_800_000_000},
  {"immutable-x", "IMX", "Immutable", 1.6, 2_000_000_000},
  {"algorand", "ALGO", "Algorand", 0.17, 1_400_000_000},
  {"blockstack", "STX", "Stacks", 1.8, 2_600_000_000},
  {"injective-protocol", "INJ", "Injective", 22, 2_100_000_000},
  {"fantom", "FTM", "Fantom", 0.68, 1_900_000_000},
  {"bittensor", "TAO", "Bittensor", 290, 2_100_000_000},
  {"thorchain", "RUNE", "THORChain", 4.5, 1_500_000_000},
  {"lido-dao", "LDO", "Lido DAO", 1.9, 1_700_000_000},
  {"flow", "FLOW", "Flow", 0.72, 1_100_000_000},
  {"quant-network", "QNT", "Quant", 89, 1_300_000_000},
  {"aave", "AAVE", "Aave", 95, 1_400_000_000}
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

Repo.delete_all(Coin)

coins
|> Enum.with_index(1)
|> Enum.each(fn {{coin_id, symbol, name, price, market_cap}, rank} ->
  change = (:rand.uniform() * 16 - 8) |> Float.round(2)
  volume = (market_cap * (0.02 + :rand.uniform() * 0.18)) |> Float.round(2)

  Repo.insert!(%Coin{
    rank: rank,
    coin_id: coin_id,
    symbol: symbol,
    name: name,
    price_usd: Decimal.from_float(price / 1),
    change_24h: Decimal.from_float(change),
    volume_24h: Decimal.from_float(volume),
    market_cap: Decimal.from_float(market_cap / 1),
    inserted_at: now,
    updated_at: now
  })
end)

IO.puts("Seeded #{length(coins)} coins")
