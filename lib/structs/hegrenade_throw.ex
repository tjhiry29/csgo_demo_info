defmodule HegrenadeThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
    time_elapsed: 0,
    time_left_in_round: 0,
    total_damage_dealt: 0,
    player_damage_dealt: %{},
    detonated: false
  ]

  def is_hegrenade_throw(%HegrenadeThrow{} = _) do
    true
  end

  def is_hegrenade_throw(_) do
    false
  end

  def update_damage_dealt(%HegrenadeThrow{} = hegrenade_throw, nil, _) do
    hegrenade_throw
  end

  def update_damage_dealt(%HegrenadeThrow{} = hegrenade_throw, user_id, event) do
    dmg = GameEvent.get_dmg_health(event)

    hegrenade_throw
    |> HegrenadeThrow.update_player_damage_dealt(user_id, dmg)
    |> HegrenadeThrow.update_total_damage_dealt(dmg)
  end

  def update_total_damage_dealt(%HegrenadeThrow{} = hegrenade_throw, dmg) do
    %{hegrenade_throw | total_damage_dealt: hegrenade_throw.total_damage_dealt + dmg}
  end

  def update_player_damage_dealt(%HegrenadeThrow{} = hegrenade_throw, user_id, dmg) do
    {_, map} =
      Map.get_and_update(hegrenade_throw.player_damage_dealt, user_id, fn val ->
        new_val =
          cond do
            val == nil -> dmg
            true -> dmg + val
          end

        {val, new_val}
      end)

    %{hegrenade_throw | player_damage_dealt: map}
  end
end
