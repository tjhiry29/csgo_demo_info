defmodule PlayerRoundRecord do
  defstruct [
    :name,
    :id,
    :team,
    :teamnum,
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

  def replace_player(player_round_records, nil, _) do
    player_round_records
  end

  def replace_player(player_round_records, _, nil) do
    player_round_records
  end

  def replace_player(player_round_records, index, player) do
    List.replace_at(player_round_records, index, player)
  end

  def replace_grenade_throw(player, grenade_throw) do
    index = find_grenade_index(player, grenade_throw.tick)
    replace_grenade_throw_at(player, index, grenade_throw)
  end

  def replace_grenade_throw_at(player, nil, _) do
    player
  end

  def replace_grenade_throw_at(player, index, grenade_throw) do
    %{
      player
      | grenade_throws: List.replace_at(player.grenade_throws, index, grenade_throw)
    }
  end

  def find_grenade_index(player, tick) do
    Enum.find_index(player.grenade_throws, fn gt ->
      gt.tick == tick
    end)
  end

  def update_attacker_damage_dealt(nil, _, _) do
    nil
  end

  def update_attacker_damage_dealt(attacker, dmg_dealt, id) do
    {_, map} =
      Map.get_and_update(attacker.damage_dealt, id, fn val ->
        new_val =
          cond do
            dmg_dealt > 100 -> 100
            val == nil -> dmg_dealt
            val + dmg_dealt > 100 -> 100
            true -> val + dmg_dealt
          end

        {val, new_val}
      end)

    %{attacker | damage_dealt: map}
  end
end
