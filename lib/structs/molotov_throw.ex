defmodule MolotovThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :location,
    total_damage_dealt: 0,
    players_damaged: [],
    player_damage_dealt: []
  ]
end
