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

  def parse_game_events(file_name) do
    if File.exists?("results/#{file_name}.dump") do
      # parse dump
      stream = File.stream!("results/#{file_name}.dump")
      {server_info, dump_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      tick_rate = round(1 / tick_rate)

      result =
        dump_stream
        |> Enum.map(&String.trim_trailing(&1, "\n"))
        |> Enum.map_reduce(nil, &parse_dump_line(&1, &2))

      {list, _} = result
      list = list |> Enum.filter(fn x -> x != nil end)

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

      IO.inspect(adr)
      # IO.inspect players_map
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

    {player_round_records, _} =
      Enum.reduce(
        events,
        {player_round_records, []},
        &process_round_game_events(&1, &2, round_num)
      )

    Map.put(acc, round_num, player_round_records)
  end

  defp process_round_game_events(event, acc, round_num) do
    {player_round_records, tmp_events} = acc

    tmp_events =
      case event.type do
        "player_hurt" ->
          {attacker, attacker_index, user, user_index} =
            process_player_hurt_event(event, player_round_records)

          player_round_records = List.replace_at(player_round_records, user_index, user)

          {player_round_records, tmp_events} =
            if attacker == nil && attacker_index == nil do
              {player_round_records, tmp_events}
            else
              player_round_records =
                List.replace_at(player_round_records, attacker_index, attacker)

              {player_round_records, tmp_events}
            end

          {player_round_records, tmp_events}

        "player_death" ->
          acc

        "weapon_fire" ->
          acc

        "player_blind" ->
          acc

        _ ->
          acc
      end
  end

  # TODO: when a player gets hurt reduce its health by the dmg_health amount.
  # take that into account when calculating the damage dealt. (might not actually be 100 damage dealt)
  defp process_player_hurt_event(event, player_round_records) do
    [_, id] = process_player_field(event)
    user_index = Enum.find_index(player_round_records, fn p -> p.id == id end)
    user = Enum.at(player_round_records, user_index)
    dmg_dealt = event.fields |> Map.get("dmg_health") |> String.to_integer()

    health = user.health - dmg_dealt
    new_health = if health < 0, do: 0, else: health

    dmg_dealt = if new_health == 0 && dmg_dealt < 100, do: health, else: dmg_dealt
    user = %{user | health: new_health}

    if Map.get(event.fields, "attacker") == "0" do
      {nil, nil, user, user_index}
    else
      [_, attacker_id] = process_player_field(event, "attacker")
      attacker_index = Enum.find_index(player_round_records, fn p -> p.id == attacker_id end)
      attacker = Enum.at(player_round_records, attacker_index)

      {_, map} =
        Map.get_and_update(attacker.damage_dealt, id, fn val ->
          new_val =
            if val == nil do
              dmg_dealt
            else
              val + dmg_dealt
            end

          new_val =
            if new_val > 100 do
              100
            else
              new_val
            end

          {val, new_val}
        end)

      attacker = %{attacker | damage_dealt: map}
      {attacker, attacker_index, user, user_index}
    end
  end

  defp process_player_death_event(event) do
    event
  end

  defp process_weapon_fire_event(event) do
    event
  end

  defp process_player_blind_event(event) do
    event
  end

  defp create_player_round_records(players, round_num) do
    Enum.map(players, fn player_event ->
      [name, id] = process_player_field(player_event)

      team = Map.get(player_event.fields, "team")
      %PlayerRoundRecord{name: name, id: id, team: team, round: round_num}
    end)
  end

  defp process_player_field(event, field \\ "userid") do
    [name, id_field] = Map.get(event.fields, field) |> String.split(" ")

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
