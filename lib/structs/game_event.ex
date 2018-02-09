defmodule GameEvent do
  defstruct [:type, fields: %{}]

  def is_game_event(%GameEvent{}) do
    true
  end

  def is_game_event(_) do
    false
  end

  def get_round(%GameEvent{} = event),
    do: Map.get(event.fields, "round_num") |> String.to_integer()

  def get_tick(%GameEvent{} = event), do: Map.get(event.fields, "tick") |> String.to_integer()
  def get_headshot(%GameEvent{} = event), do: Map.get(event.fields, "headshot") == "1"
  def get_weapon(%GameEvent{} = event), do: Map.get(event.fields, "weapon")
  def get_facing(%GameEvent{} = event), do: Map.get(event.fields, "facing")

  def get_kill_info(%GameEvent{} = event) do
    {
      get_round(event),
      get_tick(event),
      get_headshot(event),
      get_weapon(event)
    }
  end

  def get_grenade_throw_info(%GameEvent{} = event) do
    {
      get_tick(event),
      get_round(event),
      get_position(event),
      get_facing(event)
    }
  end

  def get_position(%GameEvent{} = event, index) when index > 1 do
    Map.get(event.fields, "position" <> "_#{index}")
  end

  def get_position(%GameEvent{} = event, _) do
    get_position(event)
  end

  def get_position(%GameEvent{} = event) do
    Map.get(event.fields, "position")
  end
end
