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

  def get_attacker(%GameEvent{} = event), do: Map.get(event.fields, "attacker")
  def get_tick(%GameEvent{} = event), do: Map.get(event.fields, "tick") |> String.to_integer()
  def get_headshot(%GameEvent{} = event), do: Map.get(event.fields, "headshot") == "1"
  def get_weapon(%GameEvent{} = event), do: Map.get(event.fields, "weapon")
  def get_facing(%GameEvent{} = event), do: Map.get(event.fields, "facing")
  def get_team(event), do: Map.get(event.fields, "team")

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

  def get_position(%GameEvent{} = event, _), do: get_position(event)

  def get_position(%GameEvent{} = event) do
    Map.get(event.fields, "position")
  end

  def get_xyz_location(event) do
    event
    |> get_xyz()
    |> Enum.join(", ")
  end

  def get_xyz(event) do
    [Map.get(event.fields, "x"), Map.get(event.fields, "y"), Map.get(event.fields, "z")]
  end

  def process_player_field(event, fields \\ "userid")

  def process_player_field(%GameEvent{} = event, field) do
    do_process_player_field(event.fields, field)
  end

  def process_player_field(fields, field) do
    do_process_player_field(fields, field)
  end

  def do_process_player_field(fields, field) do
    [head | tail] = Map.get(fields, field) |> String.split(" ") |> Enum.reverse()
    id_field = head

    name =
      case length(tail) do
        1 -> Enum.at(tail, 0)
        _ -> Enum.join(tail, " ")
      end

    id =
      id_field
      |> String.trim_leading("(id:")
      |> String.trim_trailing(")")
      |> String.to_integer()

    [name, id]
  end
end
