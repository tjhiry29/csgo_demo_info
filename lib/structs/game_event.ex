defmodule GameEvent do
  defstruct [:type, fields: %{}]

  def is_game_event(%GameEvent{}) do
    true
  end

  def is_game_event(_) do
    false
  end

  def get(%GameEvent{} = event) do
    fn field -> Map.get(event.fields, field) end
  end

  def get_round(%GameEvent{fields: %{"round_num" => round_num}}),
    do: round_num |> String.to_integer()

  # Occasionally there is no weapon.
  def get_weapon(%GameEvent{} = event), do: Map.get(event.fields, "weapon")
  def get_weapon(%GameEvent{fields: %{"weapon" => weapon}}) when is_bitstring(weapon), do: weapon

  def get_attacker(%GameEvent{fields: %{"attacker" => attacker}}), do: attacker
  def get_assister(%GameEvent{fields: %{"assister" => assister}}), do: assister
  def get_tick(%GameEvent{fields: %{"tick" => tick}}), do: tick |> String.to_integer()

  def get_entityid(%GameEvent{fields: %{"entityid" => entityid}}),
    do: entityid |> String.to_integer()

  def get_headshot(%GameEvent{fields: %{"headshot" => headshot}}), do: headshot == "1"
  def get_facing(%GameEvent{fields: %{"facing" => facing}}), do: facing
  def get_team(%GameEvent{fields: %{"team" => team}}), do: team

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

  def process_player_field(%GameEvent{fields: fields}, field) do
    do_process_player_field(fields, field)
  end

  def process_player_field(fields, field) do
    do_process_player_field(fields, field)
  end

  defp do_process_player_field(fields, field) do
    [head | tail] = fields |> Map.get(field) |> String.split(" ") |> Enum.reverse()
    id_field = head

    name = Enum.join(tail, " ")

    id =
      id_field
      |> String.trim_leading("(id:")
      |> String.trim_trailing(")")
      |> String.to_integer()

    {name, id}
  end

  def update_events(events, nil, _), do: events
  def update_events(events, event_index, nil), do: List.delete_at(events, event_index)

  def update_events(events, event_index, event) do
    events
    |> List.delete_at(event_index)
    |> List.insert_at(0, event)
  end

  def find_hegrenade_detonate(tmp_events, attacker_id) do
    Enum.find_index(tmp_events, fn e ->
      is_game_event(e) && e.type == "hegrenade_detonate" &&
        Map.get(e.fields, "hegrenade_throw").player_id == attacker_id && get_dmg_health(e) != 1
    end)
  end

  def find_flashbang_detonate(tmp_events, attacker_id, event) do
    Enum.find_index(tmp_events, fn e ->
      is_game_event(e) && e.type == "flashbang_detonate" && get_tick(e) == get_tick(event) &&
        Map.get(e.fields, "flashbang_throw").player_id == attacker_id
    end)
  end

  def find_inferno_startburn(tmp_events, attacker_id) do
    Enum.find_index(tmp_events, fn e ->
      is_game_event(e) && e.type == "inferno_startburn" &&
        Map.get(e.fields, "molotov_throw").player_id == attacker_id && get_dmg_health(e) != 1
    end)
  end
end
