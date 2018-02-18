defmodule SmokegrenadeThrow do
  defstruct [
    :player_name,
    :player_id,
    :tick,
    :round,
    :origin,
    :facing,
    :location,
    detonated: false
  ]

  def is_smokegrenade_throw(%SmokegrenadeThrow{}), do: true
  def is_smokegrenade_throw(_), do: false
end
