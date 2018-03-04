defmodule Player do
  defstruct [
    :name,
    :id,
    :adr,
    :kast,
    :teamnum,
    kill_count: 0,
    assist_count: 0,
    death_count: 0,
    headshot_count: 0,
    first_kills: 0,
    first_deaths: 0,
    trade_kills: 0,
    deaths_traded: 0,
    kills: [],
    assists: [],
    deaths: [],
    grenade_throws: []
  ]

  def aggregate_round_stats(player_round_records) do
    adr = calculate_adr(player_round_records)
    kast = calculate_kast(player_round_records)

    {kills, assists, deaths, grenade_throws, deaths_traded} =
      Enum.reduce(player_round_records, {[], [], [], [], 0}, fn player, acc ->
        {kills, assists, deaths, grenade_throws, deaths_traded} = acc
        kills = kills ++ player.kills
        assists = assists ++ player.assists
        deaths = deaths ++ [player.death]
        grenade_throws = grenade_throws ++ player.grenade_throws
        deaths_traded = if player.traded, do: deaths_traded + 1, else: deaths_traded
        {kills, assists, deaths, grenade_throws, deaths_traded}
      end)

    deaths = Enum.filter(deaths, fn d -> d != nil end)
    headshots = Enum.filter(kills, fn k -> k.headshot end)
    first_kills = Enum.filter(kills, fn k -> k.first_of_round end)
    first_deaths = Enum.filter(deaths, fn k -> k.first_of_round end)
    trade_kills = Enum.filter(kills, fn k -> k.trade end)
    [player | _] = player_round_records

    %Player{
      name: player.name,
      id: player.id,
      adr: adr,
      kast: kast,
      kill_count: length(kills),
      assist_count: length(assists),
      death_count: length(deaths),
      headshot_count: length(headshots),
      first_kills: length(first_kills),
      first_deaths: length(first_deaths),
      trade_kills: length(trade_kills),
      deaths_traded: deaths_traded,
      kills: kills,
      assists: assists,
      deaths: deaths,
      grenade_throws: grenade_throws,
      teamnum: player.teamnum
    }
  end

  def was_traded(player_round_records, tick_rate) do
    Enum.map(player_round_records, fn player ->
      if player.dead do
        attacker_name = player.death.attacker_name

        attacker_index =
          player_round_records
          |> Enum.find_index(fn p -> p.name == attacker_name end)

        case attacker_index do
          nil ->
            player

          _ ->
            attacker = Enum.at(player_round_records, attacker_index)

            attacker_dead =
              attacker.dead && attacker.death.tick <= player.death.tick + 5 * tick_rate

            %{player | traded: attacker_dead}
        end
      else
        player
      end
    end)
  end

  def calculate_adr(player_round_records) do
    total_dmg =
      Enum.reduce(player_round_records, 0, fn p, acc ->
        Enum.reduce(p.damage_dealt, 0, fn {_, d}, a -> d + a end) + acc
      end)

    total_dmg / length(player_round_records)
  end

  def calculate_kast(player_round_records) do
    kast_score =
      Enum.reduce(player_round_records, 0, fn p, acc ->
        if p.traded || !p.dead || !Enum.empty?(p.kills) || !Enum.empty?(p.assists) do
          acc + 1
        else
          acc
        end
      end)

    kast_score / length(player_round_records) * 100
  end
end
