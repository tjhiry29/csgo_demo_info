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

  def get_blind_duration(%GameEvent{fields: %{"blind_duration" => blind_duration}}),
    do: blind_duration |> String.to_float()

  def get_blind_duration(_), do: nil

  def get_dmg_health(%GameEvent{fields: %{"dmg_health" => dmg_health}}),
    do: dmg_health |> String.to_integer()

  def get_dmg_health(_) do
    nil
  end

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

  def get_attacker_position(%GameEvent{} = event) do
    get_position(event, 2)
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

  def get_xyz(%GameEvent{fields: %{"x" => x, "y" => y, "z" => z}}) do
    [x, y, z]
  end

  def get_xyz(_) do
    []
  end

  def process_player_field(event, fields \\ "userid")

  def process_player_field(%GameEvent{} = event, field) do
    do_process_player_field(event.fields, field)
  end

  def process_player_field(fields, field) do
    do_process_player_field(fields, field)
  end

  defp do_process_player_field(fields, field) do
    [head | tail] = Map.get(fields, field) |> String.split(" ") |> Enum.reverse()
    id_field = head

    name = Enum.join(tail, " ")

    id =
      id_field
      |> String.trim_leading("(id:")
      |> String.trim_trailing(")")
      |> String.to_integer()

    {name, id}
  end

  def find_hegrenade_detonate(tmp_events, attacker_id) do
    Enum.find_index(tmp_events, fn e ->
      GameEvent.is_game_event(e) && e.type == "hegrenade_detonate" &&
        Map.get(e.fields, "hegrenade_throw").player_id == attacker_id &&
        GameEvent.get_dmg_health(e) != 1
    end)
  end

  def find_flashbang_detonate(tmp_events, attacker_id, event) do
    Enum.find_index(tmp_events, fn e ->
      GameEvent.is_game_event(e) && e.type == "flashbang_detonate" &&
        get_tick(e) == get_tick(event) &&
        Map.get(e.fields, "flashbang_throw").player_id == attacker_id
    end)
  end
end
