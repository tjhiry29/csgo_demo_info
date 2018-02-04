defmodule GameEvent do
  defstruct [:type, fields: %{}]

  def is_game_event?(%GameEvent{}) do
    true
  end

  def is_game_event?(_) do
    false
  end
end
