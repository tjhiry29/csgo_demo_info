defmodule PlayerRoundRecord do
  defstruct [
    :name,
    :id,
    :team,
    :round,
    assists: [],
    damage_dealt: %{},
    dead: false,
    death: nil,
    flash_assists: 0,
    grenade_throws: [],
    health: 100,
    kills: [],
    traded: false
  ]

  def replace_players(player_round_records, [i | remaining_indices], [p | remaining_players]) do
    player_round_records
    |> replace_player(i, p)
    |> replace_players(remaining_indices, remaining_players)
  end

  def replace_players(player_round_records, [], []) do
    player_round_records
  end

  # Player round records only has 10 items, so nil indices are replaced by an out of bounds index.
  def replace_player(player_round_records, nil, player) do
    List.replace_at(player_round_records, 11, player)
  end

  def replace_player(player_round_records, index, player) do
    List.replace_at(player_round_records, index, player)
  end

  def update_attacker_damage_dealt(nil, _, _) do
    nil
  end

  def update_attacker_damage_dealt(attacker, dmg_dealt, id) do
    {_, map} =
      Map.get_and_update(attacker.damage_dealt, id, fn val ->
        new_val =
          cond do
            val == nil -> dmg_dealt
            val + dmg_dealt > 100 -> 100
            true -> val + dmg_dealt
          end

        {val, new_val}
      end)

    %{attacker | damage_dealt: map}
  end
end
