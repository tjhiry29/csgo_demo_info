defmodule Player do
  defstruct [:name, :id, :adr, :kast, kills: [], assists: [], deaths: [], grenade_throws: []]

  def calculate_adr(player_round_records) do
    total_dmg =
      Enum.reduce(player_round_records, 0, fn p, acc ->
        Enum.reduce(p.damage_dealt, 0, fn {_, d}, a -> d + a end) + acc
      end)

    total_dmg / length(player_round_records)
  end
end
