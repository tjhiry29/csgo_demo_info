defmodule ResultsParser.DumpParser do
  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"
  @map_name_key "map_name:"
  @filter_events [
    "round_freeze_end",
    "round_poststart",
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
      tick_rate = server_info |> get_tick_rate() |> reciprocal.() |> round()
      map_name = get_map_name(server_info)

      # create events list
      list =
        dump_stream
        |> Stream.map(&String.trim_trailing(&1, "\n"))
        |> Stream.scan({nil, nil}, &parse_dump_line(&1, &2))
        |> Enum.map(fn {e, _} ->
          e
        end)
        |> Enum.filter(fn x -> x != nil end)

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

      {first_half_players, second_half_players} =
        list
        |> Enum.filter(player_event_filter)
        |> Enum.take(20)
        |> (&{Enum.slice(&1, 0, 10), Enum.slice(&1, 10, 10)}).()

      # process game events and assign them to players per round.
      # We will process each round and events by round.
      players_map =
        events_list
        |> Enum.group_by(fn x -> x.fields |> Map.get("round_num") |> String.to_integer() end)
        |> Enum.reduce(%{}, fn {round_num, events}, acc ->
          process_round(events, acc, round_num, first_half_players, second_half_players)
        end)

      kills_by_round =
        players_map
        |> Enum.flat_map(fn {_, players} ->
          kills =
            players
            |> Enum.flat_map(fn player ->
              player.kills
            end)
            |> Kill.find_first_kills()

          Enum.map(kills, fn k ->
            %{k | map_name: map_name} |> Kill.find_trades(tick_rate, kills)
          end)
        end)
        |> Enum.group_by(fn k -> k.round end)

      players_by_id =
        players_map
        |> Enum.flat_map(fn {round_num, players} ->
          players =
            players
            |> Enum.map(fn p ->
              map_kills(p, Map.get(kills_by_round, round_num))
            end)
            |> Player.was_traded(tick_rate)
        end)
        |> Enum.group_by(fn p -> p.id end)

      players =
        players_by_id
        |> Enum.map(fn {_, players} ->
          Player.aggregate_round_stats(players)
        end)

      IO.inspect players
      players
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

        round_num > 30 ->
          ot_player_spawns = Enum.filter(events, fn e -> e.type == "player_spawn" end)
          GameEventParser.create_player_round_records(ot_player_spawns, round_num)

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
    case event.type do
      "player_hurt" ->
        {player_round_records, tmp_events} = GameEventParser.process_player_hurt_event(acc, event)

        {player_round_records, tmp_events} =
          case GameEvent.get_weapon(event) do
            "hegrenade" ->
              GameEventParser.process_grenade_hit_event({player_round_records, tmp_events}, event)

            "inferno" ->
              GameEventParser.process_inferno_hit_event({player_round_records, tmp_events}, event)

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
        GameEventParser.process_smokegrenade_detonate_event(acc, event)

      "inferno_startburn" ->
        GameEventParser.process_inferno_startburn_event(acc, event)

      "inferno_expire" ->
        GameEventParser.process_inferno_expire_event(acc, event)

      _ ->
        acc
    end
  end

  defp get_map_name(server_info) do
    map_name_chunk =
      server_info
      |> Enum.filter(fn e ->
        e |> String.split(" ") |> Enum.at(0) == @map_name_key
      end)

    map_name_chunk
    |> Enum.at(0)
    |> String.split(" ")
    |> Enum.at(1)
    |> String.trim_leading("\"")
    |> String.trim_trailing("\"\n")
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
    {_, acc} = acc

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
            1 -> tail |> Enum.at(0) |> String.trim_trailing(" ") |> String.trim_leading(" ")
            _ -> tail |> Enum.join(" ") |> String.trim_trailing(" ") |> String.trim_leading(" ")
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

  defp map_kills(player, kills) do
    [player_kills, player_assists, player_deaths] =
      Enum.reduce(kills, [[], [], []], fn kill, acc ->
        k = if kill.attacker_name == player.name, do: kill

        assist =
          if kill.assist != nil && kill.assist.assister_name == player.name, do: kill.assist

        death = if kill.victim_name == player.name, do: kill

        kills =
          if k != nil do
            acc |> Enum.at(0) |> List.insert_at(-1, k)
          else
            Enum.at(acc, 0)
          end

        assists =
          if assist != nil do
            acc |> Enum.at(1) |> List.insert_at(-1, assist)
          else
            Enum.at(acc, 1)
          end

        deaths =
          if death != nil do
            acc |> Enum.at(2) |> List.insert_at(-1, death)
          else
            Enum.at(acc, 2)
          end

        [kills, assists, deaths]
      end)

    %{player | kills: player_kills, assists: player_assists, death: Enum.at(player_deaths, 0)}
  end
end
