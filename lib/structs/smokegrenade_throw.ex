defmodule SmokegrenadeThrow do
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
    detonated: false
  ]

  def is_smokegrenade_throw(%SmokegrenadeThrow{}), do: true
  def is_smokegrenade_throw(_), do: false
end
