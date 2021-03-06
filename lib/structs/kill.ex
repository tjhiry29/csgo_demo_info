defmodule DemoInfoGo.Kill do
  @trade_time_limit 5

  defstruct [
    :attacker_name,
    :attacker_id,
    :victim_name,
    :victim_id,
    :weapon,
    :round,
    :tick,
    :headshot,
    :victim_position,
    :attacker_position,
    :map_name,
    time_elapsed: 0,
    time_left_in_round: 0,
    trade: false,
    assist: nil,
    first_of_round: false
  ]

  def find_first_kills([]) do
    []
  end

  def find_first_kills([kill | kills]) do
    kill = %{kill | first_of_round: true}
    [kill | kills]
  end

  def find_trades(kill, tick_rate, kills) do
    filtered_kills =
      kills
      |> Enum.filter(fn k ->
        k.tick < kill.tick && k.tick > kill.tick - @trade_time_limit * tick_rate &&
          k.attacker_name == kill.victim_name
      end)

    if Enum.at(filtered_kills, 0) != nil do
      %{kill | trade: true}
    else
      kill
    end
  end
end
