defmodule HegrenadeThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
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
end
