defmodule DemoInfoGo.GameEvent do
  @round_time 115

  defstruct [:type, fields: %{}]

  def is_game_event(%DemoInfoGo.GameEvent{}) do
    true
  end

  def is_game_event(_) do
    false
  end

  def get(%DemoInfoGo.GameEvent{} = event) do
    fn field -> Map.get(event.fields, field) end
  end

  def get_round(%DemoInfoGo.GameEvent{fields: %{"round_num" => round_num}}),
    do: round_num |> String.to_integer()

  def get_time_elapsed(%DemoInfoGo.GameEvent{fields: %{"time_elapsed" => time_elapsed}}),
    do: time_elapsed

  def get_time_left_in_round(%DemoInfoGo.GameEvent{
        fields: %{"time_left_in_round" => time_left_in_round}
      }),
      do: time_left_in_round

  # Occasionally there is no weapon.
  def get_weapon(%DemoInfoGo.GameEvent{} = event), do: Map.get(event.fields, "weapon")

  def get_weapon(%DemoInfoGo.GameEvent{fields: %{"weapon" => weapon}}) when is_bitstring(weapon),
    do: weapon

  def get_attacker(%DemoInfoGo.GameEvent{fields: %{"attacker" => attacker}}), do: attacker
  def get_assister(%DemoInfoGo.GameEvent{fields: %{"assister" => assister}}), do: assister
  def get_tick(%DemoInfoGo.GameEvent{fields: %{"tick" => tick}}), do: tick |> String.to_integer()
  def get_tick(_), do: 0

  def get_entityid(%DemoInfoGo.GameEvent{fields: %{"entityid" => entityid}}),
    do: entityid |> String.to_integer()

  def get_headshot(%DemoInfoGo.GameEvent{fields: %{"headshot" => headshot}}), do: headshot == "1"
  def get_facing(%DemoInfoGo.GameEvent{fields: %{"facing" => facing}}), do: facing
  def get_team(%DemoInfoGo.GameEvent{fields: %{"team" => team}}), do: team
  def get_team(_), do: nil
  def get_teamnum(%DemoInfoGo.GameEvent{fields: %{"teamnum" => teamnum}}), do: teamnum
  def get_teamnum(_), do: nil
  def get_winner(%DemoInfoGo.GameEvent{fields: %{"winner" => winner}}), do: winner
  def get_winner(_), do: nil

  def get_blind_duration(%DemoInfoGo.GameEvent{fields: %{"blind_duration" => blind_duration}}),
    do: blind_duration |> String.to_float()

  def get_blind_duration(_), do: nil

  def get_dmg_health(%DemoInfoGo.GameEvent{fields: %{"dmg_health" => dmg_health}}),
    do: dmg_health |> String.to_integer()

  def get_dmg_health(_), do: 0

  def get_kill_info(%DemoInfoGo.GameEvent{} = event) do
    {
      get_round(event),
      get_tick(event),
      get_headshot(event),
      get_weapon(event)
    }
  end

  def get_grenade_throw_info(%DemoInfoGo.GameEvent{} = event) do
    {
      get_tick(event),
      get_round(event),
      get_position(event),
      get_facing(event)
    }
  end

  def get_attacker_position(%DemoInfoGo.GameEvent{} = event) do
    get_position(event, 2)
  end

  def get_position(%DemoInfoGo.GameEvent{} = event, index) when index > 1 do
    event.fields
    |> Map.get("position" <> "_#{index}")
    |> String.split(", ")
    |> Enum.map(&String.to_float/1)
  end

  def get_position(%DemoInfoGo.GameEvent{} = event, _), do: get_position(event)

  def get_position(%DemoInfoGo.GameEvent{fields: %{"position" => position}}) do
    position
    |> String.split(", ")
    |> Enum.map(&String.to_float/1)
  end

  def get_xyz_location(event) do
    event
    |> get_xyz()
    |> Enum.map(&String.to_float/1)
  end

  def get_xyz(%DemoInfoGo.GameEvent{fields: %{"x" => x, "y" => y, "z" => z}}) do
    [x, y, z]
  end

  def get_xyz(_) do
    []
  end

  def process_player_field(event, fields \\ "userid")

  def process_player_field(%DemoInfoGo.GameEvent{fields: fields}, field) do
    do_process_player_field(fields, field)
  end

  def process_player_field(fields, field) do
    do_process_player_field(fields, field)
  end

  defp do_process_player_field(fields, field) do
    [head | tail] = fields |> Map.get(field) |> String.split(" ") |> Enum.reverse()
    id_field = head

    name = tail |> Enum.reverse() |> Enum.join(" ")

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

  def time_left_in_round(%DemoInfoGo.GameEvent{} = event, start_tick, tick_rate) do
    current_tick = get_tick(event)
    tick_difference = current_tick - start_tick
    time_elapsed = tick_difference / tick_rate
    time_left_in_round = @round_time - time_elapsed

    fields =
      event.fields
      |> Map.put("time_elapsed", time_elapsed)
      |> Map.put("time_left_in_round", time_left_in_round)

    %{event | fields: fields}
  end
end
