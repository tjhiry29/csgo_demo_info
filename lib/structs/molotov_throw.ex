defmodule MolotovThrow do
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
    detonated: false,
    expired: false,
    entityid: nil,
    total_damage_dealt: 0,
    player_damage_dealt: %{}
  ]

  def is_molotov_throw(%MolotovThrow{}), do: true
  def is_molotov_throw(_), do: false

  def update_damage_dealt(%MolotovThrow{} = molotov_throw, user_id, event) do
    dmg = GameEvent.get_dmg_health(event)

    molotov_throw
    |> MolotovThrow.update_player_damage_dealt(user_id, dmg)
    |> MolotovThrow.update_total_damage_dealt(dmg)
  end

  def update_total_damage_dealt(%MolotovThrow{} = molotov_throw, dmg) do
    %{molotov_throw | total_damage_dealt: molotov_throw.total_damage_dealt + dmg}
  end

  def update_player_damage_dealt(%MolotovThrow{} = molotov_throw, user_id, dmg) do
    {_, map} =
      Map.get_and_update(molotov_throw.player_damage_dealt, user_id, fn val ->
        new_val =
          cond do
            val == nil -> dmg
            true -> dmg + val
          end

        {val, new_val}
      end)

    %{molotov_throw | player_damage_dealt: map}
  end
end
