defmodule FlashbangThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
    player_blind_duration: %{},
    total_blind_duration: 0,
    flash_assist: false,
    detonated: false
  ]

  def is_flashbang_throw(%FlashbangThrow{}) do
    true
  end

  def is_flashbang_throw(_) do
    false
  end
end
