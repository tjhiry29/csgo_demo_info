defmodule ResultsParser.DumpParser do
  alias GameEvent, as: GameEvent

  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"
  @filter_events [
    "round_announce_match_point",
    "decoy_started",
    "announce_phase_end",
    "round_time_warning",
    "round_announce_last_round_half",
    "cs_round_final_beep",
    "cs_pre_restart",
    "cs_win_panel_round",
    "player_team",
    "cs_win_panel_round",
    "decoy_detonate",
    "round_freeze_end",
    "round_poststart",
    "hltv_fixed",
    "round_officially_ended",
    "round_announce_match_start",
    "round_end"
  ]
  @grenades [
    "weapon_flashbang",
    "weapon_molotov",
    "weapon_smokegrenade",
    "weapon_hegrenade",
    "weapon_incgrenade"
  ]

  def parse_game_events(file_name) do
    if File.exists?("results/#{file_name}.dump") do
      # parse dump
      stream = File.stream!("results/#{file_name}.dump")
      {server_info, dump_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      tick_rate = round(1 / tick_rate)

      # create events list
      result =
        dump_stream
        |> Enum.map(&String.trim_trailing(&1, "\n"))
        |> Enum.map_reduce(nil, &parse_dump_line(&1, &2))

      {list, _} = result
      list = list |> Enum.filter(fn x -> x != nil end)

      # order the list of events.
      events_list =
        list
        |> Enum.filter(fn x ->
          !Enum.member?(@filter_events, x.type)
        end)
        |> Enum.sort(fn e1, e2 ->
          e1.fields |> Map.get("round_num") |> String.to_integer() <
            e2.fields |> Map.get("round_num") |> String.to_integer()
        end)
        |> Enum.sort(fn e1, e2 ->
          e1.fields |> Map.get("tick") |> String.to_integer() <
            e2.fields |> Map.get("tick") |> String.to_integer()
        end)

      # process player spawn events to create list of players.
      players =
        list
        |> Enum.filter(fn x -> x.type == "player_spawn" end)
        |> Enum.filter(fn x ->
          Map.get(x.fields, "round_num") |> String.to_integer() == 1 ||
            Map.get(x.fields, "round_num") |> String.to_integer() == 16
        end)
        |> Enum.take(20)

      first_half_players = Enum.slice(players, 0, 10)
      second_half_players = Enum.slice(players, 10, 10)

      # process game events and assign them to players per round.
      # We will process each round and events by round.
      players_map =
        events_list
        |> Enum.group_by(fn x -> Map.get(x.fields, "round_num") |> String.to_integer() end)
        |> Enum.reduce(%{}, fn {round_num, events}, acc ->
          process_round(events, acc, round_num, first_half_players, second_half_players)
        end)

      adr =
        players_map
        |> Enum.flat_map(fn {_, players} -> players end)
        |> Enum.group_by(fn player -> player.id end)
        |> Enum.map(fn {_, records} ->
          total_dmg =
            Enum.reduce(records, 0, fn record, a ->
              dmg_round =
                Enum.reduce(record.damage_dealt, 0, fn {_, v}, acc ->
                  v + acc
                end)

              dmg_round + a
            end)

          total_dmg / length(records)
        end)
        |> Enum.sort(fn d1, d2 -> d1 > d2 end)

      # IO.inspect(adr)
      IO.inspect Enum.at(Map.get(players_map, 29), 0)
    else
      IO.puts("No such file results/#{file_name}.dump, please check the directory 
                or ensure the demo dump goes through as expected")
    end
  end

  defp process_round(events, acc, round_num, first_half_players, second_half_players) do
    player_round_records =
      cond do
        round_num <= 15 -> create_player_round_records(first_half_players, round_num)
        round_num > 15 -> create_player_round_records(second_half_players, round_num)
      end
      |> Enum.sort(fn p1, p2 -> p1.id < p2.id end)

    {player_round_records, tmp_events} =
      Enum.reduce(
        events,
        {player_round_records, []},
        &process_round_game_events(&1, &2, round_num)
      )

    Map.put(acc, round_num, player_round_records)
  end

  defp process_round_game_events(event, acc, round_num) do
    {player_round_records, tmp_events} = acc

    case event.type do
      "player_hurt" ->
        {attacker, attacker_index, user, user_index} =
          process_player_hurt_event(event, player_round_records)

        # 11 as fallback, which is an out of range index.
        player_round_records =
          player_round_records
          |> List.replace_at(user_index, user)
          |> List.replace_at(attacker_index || 11, attacker)

        {player_round_records, tmp_events}

      "player_death" ->
        {attacker, attacker_index, user, user_index, assister, assister_index} =
          process_player_death_event(event, player_round_records)

        # 11 as fallback, which is an out of range index.
        player_round_records =
          player_round_records
          |> List.replace_at(user_index, user)
          |> List.replace_at(attacker_index, attacker)
          |> List.replace_at(assister_index || 11, assister)

        {player_round_records, tmp_events}

      "weapon_fire" ->
        cond do
          Enum.member?(@grenades, Map.get(event.fields, "weapon")) ->
            grenade_throw = process_weapon_fire_event(event)

            case grenade_throw do
              nil ->
                {player_round_records, tmp_events}

              _ ->
                user_index =
                  Enum.find_index(player_round_records, fn p ->
                    p.id == grenade_throw.player_id
                  end)

                user = Enum.at(player_round_records, user_index)
                user = %{user | grenade_throws: [grenade_throw | user.grenade_throws]}
                player_round_records = List.replace_at(player_round_records, user_index, user)
                tmp_events = [grenade_throw | tmp_events]
                {player_round_records, tmp_events}
            end

          true ->
            {player_round_records, tmp_events}
        end

      "player_blind" ->
        process_player_blind_event(event)
        acc

      "hegrenade_detonate" ->
        acc

      "flashbang_detonate" ->
        acc

      "smokegrenade_detonate" ->
        acc

      "smokegrenade_expired" ->
        acc

      "inferno_startburn" ->
        acc

      "inferno_expire" ->
        acc

      _ ->
        acc
    end
  end

  defp process_player_hurt_event(event, player_round_records) do
    [_, id] = process_player_field(event)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    user = Enum.at(player_round_records, user_index)
    dmg_dealt = event.fields |> Map.get("dmg_health") |> String.to_integer()

    health = user.health - dmg_dealt
    new_health = if health < 0, do: 0, else: health

    dmg_dealt = if new_health == 0, do: user.health, else: dmg_dealt
    user = %{user | health: new_health}

    if Map.get(event.fields, "attacker") == "0" do
      {nil, nil, user, user_index}
    else
      [_, attacker_id] = process_player_field(event, "attacker")
      attacker_index = Enum.find_index(player_round_records, fn p -> p.id == attacker_id end)
      attacker = Enum.at(player_round_records, attacker_index)

      cond do
        attacker.team == user.team ->
          {attacker, attacker_index, user, user_index}

        true ->
          {_, map} =
            Map.get_and_update(attacker.damage_dealt, id, fn val ->
              new_val =
                cond do
                  val == nil -> dmg_dealt
                  val + dmg_dealt > 100 -> 100
                  true -> val + dmg_dealt
                end

              {val, new_val}
            end)

          attacker = %{attacker | damage_dealt: map}
          {attacker, attacker_index, user, user_index}
      end
    end
  end

  defp process_player_death_event(event, player_round_records) do
    [_, id] = process_player_field(event)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    user = Enum.at(player_round_records, user_index)
    user = %{user | dead: true}
    victim_position = Map.get(event.fields, "position")
    round = Map.get(event.fields, "round_num") |> String.to_integer()
    tick = Map.get(event.fields, "tick") |> String.to_integer()
    headshot = Map.get(event.fields, "headshot") == "1"
    weapon = Map.get(event.fields, "weapon")

    if Map.get(event.fields, "attacker") == "0" do
      IO.inspect(event)
    else
      [_, attacker_id] = process_player_field(event, "attacker")
      attacker_index = Enum.find_index(player_round_records, fn p -> p.id == attacker_id end)
      attacker = Enum.at(player_round_records, attacker_index)

      attacker_position = Map.get(event.fields, "position_2")

      [_, assister_id] =
        cond do
          Map.get(event.fields, "assister") != "0" ->
            process_player_field(event, "assister")

          true ->
            [nil, nil]
        end

      assister_index = Enum.find_index(player_round_records, fn p -> p.id == assister_id end)

      {assister, assist} =
        cond do
          assister_id != nil ->
            {assister = Enum.at(player_round_records, assister_index),
             %Assist{
               victim_name: user.name,
               assister_name: Enum.at(player_round_records, assister_index).name,
               round: round,
               tick: tick
             }}

          true ->
            {nil, nil}
        end

      kill = %Kill{
        attacker_name: attacker.name,
        victim_name: user.name,
        weapon: weapon,
        round: round,
        tick: tick,
        headshot: headshot,
        victim_position: victim_position,
        attacker_position: attacker_position,
        assist: assist
      }

      user = %{user | death: kill}
      kills = [kill | attacker.kills]
      attacker = %{attacker | kills: kills}

      assister =
        if assister != nil do
          assists = [assist | assister.assists]
          %{assister | assists: assists}
        end

      {attacker, attacker_index, user, user_index, assister, assister_index}
    end
  end

  defp process_weapon_fire_event(event) do
    [player_name, player_id] = process_player_field(event)
    tick = Map.get(event.fields, "tick")
    round = Map.get(event.fields, "round_num")
    origin = Map.get(event.fields, "position")
    facing = Map.get(event.fields, "facing")

    case Map.get(event.fields, "weapon") do
      "weapon_incgrenade" ->
        %MolotovThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_molotov" ->
        %MolotovThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_flashbang" ->
        %FlashbangThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_hegrenade" ->
        %HegrenadeThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      "weapon_smokegrenade" ->
        %SmokegrenadeThrow{
          player_name: player_name,
          player_id: player_id,
          round: round,
          tick: tick,
          origin: origin,
          facing: facing
        }

      _ ->
        nil
    end
  end

  defp create_player_round_records(players, round_num) do
    Enum.map(players, fn player_event ->
      [name, id] = process_player_field(player_event)

      team = Map.get(player_event.fields, "team")
      %PlayerRoundRecord{name: name, id: id, team: team, round: round_num}
    end)
  end

  defp process_player_field(event, fields \\ "userid")

  defp process_player_field(%GameEvent{} = event, field) do
    do_process_player_field(event.fields, field)
  end

  defp process_player_field(fields, field) do
    do_process_player_field(fields, field)
  end

  defp do_process_player_field(fields, field) do
    [name, id_field] = Map.get(fields, field) |> String.split(" ")

    id =
      id_field
      |> String.trim_leading("(id:")
      |> String.trim_trailing(")")
      |> String.to_integer()

    [name, id]
  end

  defp get_tick_rate(server_info) do
    tick_rate_chunk =
      server_info
      |> Enum.filter(fn e ->
        e |> String.split(" ") |> Enum.at(0) == @tick_interval_key
      end)

    tick_rate_chunk
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
    |> String.trim_trailing("\n")
    |> String.to_float()
  end

  defp parse_dump_line(line, acc) do
    cond do
      String.contains?(line, "{") ->
        event_type = line |> String.split(" ") |> Enum.at(0)
        acc = %GameEvent{type: event_type}
        {nil, acc}

      String.contains?(line, "}") ->
        {acc, nil}

      acc != nil ->
        fields =
          line |> String.trim_trailing("\n") |> String.split(": ")
          |> Enum.map(fn str ->
            str |> String.trim_trailing(" ") |> String.trim_leading(" ")
          end)

        fields =
          if Map.has_key?(acc.fields, Enum.at(fields, 0)) do
            new_key = Enum.at(fields, 0) <> "_2"

            new_key =
              if Map.has_key?(acc.fields, new_key) do
                Enum.at(fields, 0) <> "_3"
              else
                new_key
              end

            fields = List.delete_at(fields, 0)
            List.insert_at(fields, 0, new_key)
          else
            fields
          end

        new_fields = Map.put(acc.fields, Enum.at(fields, 0), Enum.at(fields, 1))
        {nil, %{acc | fields: new_fields}}

      true ->
        {nil, acc}
    end
  end
end
