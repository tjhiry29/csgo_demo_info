defmodule FlashbangThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :location,
    players_blinded: [],
    player_blind_duration: [],
    total_blind_duration: 0,
    flash_assist: false
  ]
end
