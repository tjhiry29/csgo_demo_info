defmodule Player do
  defstruct [
    :name,
    :id,
    :adr,
    :kast,
    kill_count: 0,
    assist_count: 0,
    death_count: 0,
    headshot_count: 0,
    kills: [],
    assists: [],
    deaths: [],
    grenade_throws: []
  ]

  def was_traded(player_round_records, tick_rate) do
    Enum.map(player_round_records, fn player ->
      if player.dead do
        attacker_name = player.death.attacker_name

        attacker_index =
          player_round_records
          |> Enum.find_index(fn p -> p.name == attacker_name end)

        attacker = Enum.at(player_round_records, attacker_index)
        attacker_dead = attacker.dead && attacker.death.tick <= player.death.tick + 5 * tick_rate

        %{player | traded: attacker_dead}
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
