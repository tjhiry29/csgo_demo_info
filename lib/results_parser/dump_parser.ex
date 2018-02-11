defmodule ResultsParser.DumpParser do
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
      reciprocal = &(1 / &1)
      tick_rate = get_tick_rate(server_info) |> reciprocal.() |> round()
      # create events list
      {list, _} =
        dump_stream
        |> Stream.map(&String.trim_trailing(&1, "\n"))
        |> Enum.map_reduce(nil, &parse_dump_line(&1, &2))

      list = list |> Enum.filter(fn x -> x != nil end)

      # order the list of events.
      events_list =
        list
        |> Enum.filter(fn x ->
          !Enum.member?(@filter_events, x.type)
        end)

      # process player spawn events to create list of players.
      player_spawn = fn x -> x.type == "player_spawn" end
      first_half_event = &(GameEvent.get_round(&1) == 1)
      second_half_event = &(GameEvent.get_round(&1) == 16)

      player_event_filter =
        &(player_spawn.(&1) && (first_half_event.(&1) || second_half_event.(&1)))

      players =
        list
        |> Enum.filter(player_event_filter)
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

      # adr =
      #   players_map
      #   |> Enum.flat_map(fn {_, players} -> players end)
      #   |> Enum.group_by(fn player -> player.id end)
      #   |> Enum.map(fn {_, records} ->
      #     total_dmg =
      #       Enum.reduce(records, 0, fn record, a ->
      #         dmg_round =
      #           Enum.reduce(record.damage_dealt, 0, fn {_, v}, acc ->
      #             v + acc
      #           end)

      #         dmg_round + a
      #       end)

      #     total_dmg / length(records)
      #   end)
      #   |> Enum.sort(fn d1, d2 -> d1 > d2 end)

      # IO.inspect(adr)
      # IO.inspect(Map.get(players_map, 29))
    else
      IO.puts("No such file results/#{file_name}.dump, please check the directory 
                or ensure the demo dump goes through as expected")
    end
  end

  defp process_round(events, acc, round_num, first_half_players, second_half_players) do
    player_round_records =
      cond do
        round_num <= 15 ->
          GameEventParser.create_player_round_records(first_half_players, round_num)

        round_num > 15 ->
          GameEventParser.create_player_round_records(second_half_players, round_num)
      end
      |> Enum.sort(fn p1, p2 -> p1.id < p2.id end)

    {player_round_records, _} =
      Enum.reduce(
        events,
        {player_round_records, []},
        &process_round_game_events(&1, &2)
      )

    Map.put(acc, round_num, player_round_records)
  end

  defp process_round_game_events(event, acc) do
    {player_round_records, tmp_events} = acc

    case event.type do
      "player_hurt" ->
        {player_round_records, tmp_events} = GameEventParser.process_player_hurt_event(acc, event)

        {player_round_records, tmp_events} =
          case GameEvent.get_weapon(event) do
            "hegrenade" ->
              GameEventParser.process_grenade_hit_event(acc, event)

            "inferno" ->
              {player_round_records, tmp_events}

            _ ->
              {player_round_records, tmp_events}
          end

        {player_round_records, tmp_events}

      "player_death" ->
        GameEventParser.process_player_death_event(acc, event)

      "weapon_fire" ->
        cond do
          Enum.member?(@grenades, GameEvent.get_weapon(event)) ->
            GameEventParser.process_grenade_throw_event(acc, event)

          true ->
            acc
        end

      "player_blind" ->
        GameEventParser.process_player_blind_event(acc, event)

      "hegrenade_detonate" ->
        GameEventParser.process_hegrenade_detonate_event(acc, event)

      "flashbang_detonate" ->
        GameEventParser.process_flashbang_detonate_event(acc, event)

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
        [head | tail] = line |> String.trim_trailing("\n") |> String.split(": ")
        key = head |> String.trim_leading(" ")

        value =
          case length(tail) do
            1 -> Enum.at(tail, 0) |> String.trim_trailing(" ") |> String.trim_leading(" ")
            _ -> Enum.join(tail, " ") |> String.trim_trailing(" ") |> String.trim_leading(" ")
          end

        key =
          cond do
            Map.has_key?(acc.fields, key <> "_2") ->
              key <> "_3"

            Map.has_key?(acc.fields, key) ->
              key <> "_2"

            true ->
              key
          end

        new_fields = Map.put(acc.fields, key, value)
        {nil, %{acc | fields: new_fields}}

      true ->
        {nil, acc}
    end
  end
end
