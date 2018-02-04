defmodule MolotovThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
    total_damage_dealt: 0,
    player_damage_dealt: %{}
  ]
end
