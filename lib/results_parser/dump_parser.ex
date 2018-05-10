defmodule ResultsParser.DumpParser do
  @round_time 115
  @bomb_timer 40
  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"
  @map_name_key "map_name:"
  @filter_events [
    "round_poststart",
    "round_officially_ended"
  ]
  @grenades [
    "weapon_flashbang",
    "weapon_molotov",
    "weapon_smokegrenade",
    "weapon_hegrenade",
    "weapon_incgrenade"
  ]

  def parse_game_events(file_name, path) do
    if File.exists?("#{path}results/#{file_name}.dump") do
      # parse dump
      stream = File.stream!("#{path}results/#{file_name}.dump")
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

      match_start = Enum.find(list, fn x -> x.type == "round_announce_match_start" end)

      player_infos =
        Enum.filter(list, fn x ->
          x.type == "player_info" && Map.get(x.fields, "guid") != "BOT"
        end)

      # order the list of events.
      events_list =
        list
        |> Enum.filter(fn x ->
          !Enum.member?(@filter_events, x.type) &&
            DemoInfoGo.GameEvent.get_tick(x) >= DemoInfoGo.GameEvent.get_tick(match_start)
        end)

      [first_event | remainder] = events_list

      first_event =
        if DemoInfoGo.GameEvent.get_round(first_event) == 0 do
          fields = Map.put(first_event.fields, "round_num", "1")
          Map.put(first_event, :fields, fields)
        else
          first_event
        end

      events_list = [first_event | remainder]

      # process player spawn events to create list of players.
      player_spawn = fn x -> x.type == "player_spawn" end
      first_half_event = &(DemoInfoGo.GameEvent.get_round(&1) == 0)
      second_half_event = &(DemoInfoGo.GameEvent.get_round(&1) == 16)

      first_half_players =
        list
        |> Enum.filter(fn e ->
          player_spawn.(e) && first_half_event.(e) && DemoInfoGo.GameEvent.get_team(e) != nil
        end)
        |> Enum.reverse()
        |> Enum.take(10)

      first_half_players =
        if length(first_half_players) == 0 do
          list
          |> Enum.filter(fn e ->
            player_spawn.(e) && DemoInfoGo.GameEvent.get_round(e) == 2 &&
              DemoInfoGo.GameEvent.get_team(e) != nil
          end)
          |> Enum.uniq_by(fn e -> Map.get(e.fields, "userid") end)
          |> Enum.take(10)
        else
          first_half_players
        end

      second_half_players =
        events_list
        |> Enum.filter(fn e -> player_spawn.(e) && second_half_event.(e) end)
        |> Enum.take(10)
        |> Enum.map(fn e ->
          if Map.get(e.fields, "team") == "CT" do
            fields = Map.put(e.fields, "team", "T")
            Map.put(e, :fields, fields)
          else
            fields = Map.put(e.fields, "team", "CT")
            Map.put(e, :fields, fields)
          end
        end)

      # process game events and assign them to players per round.
      # We will process each round and events by round.
      events_by_round =
        events_list
        |> Enum.group_by(fn x -> x.fields |> Map.get("round_num") |> String.to_integer() end)
        |> Enum.sort_by(fn {roundnum, _} -> roundnum end)

      round_starts = events_list |> Enum.filter(fn e -> e.type == "round_freeze_end" end)

      players_map =
        events_by_round
        |> Enum.reduce(%{}, fn {round_num, events}, acc ->
          process_round(
            events,
            acc,
            round_num,
            first_half_players,
            second_half_players,
            round_starts,
            tick_rate
          )
        end)

      teams = post_process(tick_rate, players_map, map_name, events_by_round)

      IO.inspect(player_infos)
      IO.inspect(teams)
      # IO.inspect players
      {player_infos, teams}
    else
      IO.puts("No such file results/#{file_name}.dump, please check the directory
                or ensure the demo dump goes through as expected")
    end
  end

  defp post_process(tick_rate, players_map, map_name, events_by_round) do
    kills_by_round =
      players_map
      |> Enum.flat_map(fn {_, players} ->
        kills =
          players
          |> Enum.flat_map(fn player ->
            player.kills
          end)
          |> Enum.sort(fn k1, k2 -> k1.tick < k2.tick end)
          |> DemoInfoGo.Kill.find_first_kills()

        Enum.map(kills, fn k ->
          %{k | map_name: map_name} |> DemoInfoGo.Kill.find_trades(tick_rate, kills)
        end)
      end)
      |> Enum.group_by(fn k -> k.round end)

    players_by_id =
      players_map
      |> Enum.flat_map(fn {round_num, players} ->
        players
        |> Enum.map(fn p ->
          map_kills(p, Map.get(kills_by_round, round_num))
        end)
        |> DemoInfoGo.Player.was_traded(tick_rate)
      end)
      |> Enum.group_by(fn p -> p.id end)

    players =
      players_by_id
      |> Enum.map(fn {_, players} ->
        DemoInfoGo.Player.aggregate_round_stats(players)
      end)

    teams =
      players
      |> Enum.group_by(fn p -> p.teamnum end)
      |> Enum.map(fn {teamnum, players} ->
        %DemoInfoGo.Team{
          id: String.to_integer(teamnum),
          teamnum: teamnum,
          players: players
        }
      end)
      |> Enum.filter(fn team -> team.teamnum == "2" || team.teamnum == "3" end)

    {teams, _} =
      events_by_round
      |> Enum.reduce({teams, players}, fn {_, events}, acc ->
        {teams, players} = acc
        process_round_for_teams(events, teams, players, tick_rate)
      end)

    team1 = Enum.at(teams, 0)
    team2 = Enum.at(teams, 1)

    teams =
      cond do
        team1.rounds_won > team2.rounds_won ->
          [%{team1 | won: true}, %{team2 | won: false}]

        team2.rounds_won > team1.rounds_won ->
          [%{team1 | won: false}, %{team2 | won: true}]

        team1.rounds_won == team2.rounds_won ->
          [%{team1 | won: false, tie: true}, %{team2 | won: false, tie: true}]
      end

    teams =
      teams
      |> Enum.map(fn team ->
        new_players =
          team.players
          |> Enum.map(fn player ->
            %{
              player
              | won: team.won,
                tie: team.tie,
                rounds_won: team.rounds_won,
                rounds_lost: team.rounds_lost
            }
          end)

        %{team | players: new_players}
      end)

    teams
  end

  defp process_round(
         events,
         acc,
         round_num,
         first_half_players,
         second_half_players,
         round_starts,
         tick_rate
       ) do
    player_spawns = Enum.filter(events, fn e -> e.type == "player_spawn" end)
    player_spawns = Enum.uniq_by(player_spawns, fn e -> Map.get(e.fields, "userid") end)

    player_spawns =
      if length(player_spawns) == 0 do
        cond do
          round_num <= 15 ->
            first_half_players

          round_num > 15 ->
            second_half_players

          true ->
            first_half_players
        end
      else
        player_spawns
      end

    player_round_records =
      cond do
        round_num <= 15 ->
          ResultsParser.GameEventParser.create_player_round_records(player_spawns, round_num)

        round_num > 15 ->
          ResultsParser.GameEventParser.create_player_round_records(player_spawns, round_num)

        round_num > 30 ->
          ResultsParser.GameEventParser.create_player_round_records(player_spawns, round_num)
      end
      |> Enum.sort(fn p1, p2 -> p1.id < p2.id end)

    round_start =
      round_starts
      |> Enum.find(fn e -> DemoInfoGo.GameEvent.get_round(e) == round_num end)

    {player_round_records, _} =
      events
      |> Enum.map(fn e ->
        DemoInfoGo.GameEvent.time_left_in_round(
          e,
          DemoInfoGo.GameEvent.get_tick(round_start),
          tick_rate
        )
      end)
      |> Enum.reduce(
        {player_round_records, []},
        &process_round_game_events(&1, &2)
      )

    Map.put(acc, round_num, player_round_records)
  end

  defp process_round_game_events(event, acc) do
    case event.type do
      "player_hurt" ->
        {player_round_records, tmp_events} =
          ResultsParser.GameEventParser.process_player_hurt_event(acc, event)

        {player_round_records, tmp_events} =
          case DemoInfoGo.GameEvent.get_weapon(event) do
            "hegrenade" ->
              ResultsParser.GameEventParser.process_grenade_hit_event(
                {player_round_records, tmp_events},
                event
              )

            "inferno" ->
              ResultsParser.GameEventParser.process_inferno_hit_event(
                {player_round_records, tmp_events},
                event
              )

            _ ->
              {player_round_records, tmp_events}
          end

        {player_round_records, tmp_events}

      "player_death" ->
        ResultsParser.GameEventParser.process_player_death_event(acc, event)

      "weapon_fire" ->
        cond do
          Enum.member?(@grenades, DemoInfoGo.GameEvent.get_weapon(event)) ->
            ResultsParser.GameEventParser.process_grenade_throw_event(acc, event)

          true ->
            acc
        end

      "player_blind" ->
        ResultsParser.GameEventParser.process_player_blind_event(acc, event)

      "hegrenade_detonate" ->
        ResultsParser.GameEventParser.process_hegrenade_detonate_event(acc, event)

      "flashbang_detonate" ->
        ResultsParser.GameEventParser.process_flashbang_detonate_event(acc, event)

      "smokegrenade_detonate" ->
        ResultsParser.GameEventParser.process_smokegrenade_detonate_event(acc, event)

      "inferno_startburn" ->
        ResultsParser.GameEventParser.process_inferno_startburn_event(acc, event)

      "inferno_expire" ->
        ResultsParser.GameEventParser.process_inferno_expire_event(acc, event)

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
        acc = %DemoInfoGo.GameEvent{type: event_type}
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
        k = if kill.attacker_id == player.id, do: kill

        assist = if kill.assist != nil && kill.assist.assister_id == player.id, do: kill.assist

        death = if kill.victim_id == player.id, do: kill

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

    player_kills = Enum.uniq_by(player_kills, fn k -> k.round && k.victim_id end)
    %{player | kills: player_kills, assists: player_assists, death: Enum.at(player_deaths, 0)}
  end

  defp process_round_for_teams(events, teams, players, tick_rate) do
    {teams, players, _, _} =
      Enum.reduce(events, {teams, players, [], []}, fn event, acc ->
        {teams, players, tmp_events, player_teams} = acc

        case event.type do
          "round_announce_match_start" ->
            tmp_events = [event | tmp_events]
            {teams, players, tmp_events, player_teams}

          "round_freeze_end" ->
            tmp_events = [event | tmp_events]
            {teams, players, tmp_events, player_teams}

          "player_team" ->
            player_teams = [event | player_teams]
            {_, id} = DemoInfoGo.GameEvent.process_player_field(event)
            player_index = Enum.find_index(players, fn p -> p.id == id end)
            player = Enum.at(players, player_index)

            teams =
              if length(player_teams) == 10 do
                [team1, team2] = teams
                teamnum1 = team1.teamnum
                teamnum2 = team2.teamnum
                team1 = %{team1 | teamnum: teamnum2}
                team2 = %{team2 | teamnum: teamnum1}
                [team1, team2]
              else
                teams
              end

            player = %{player | teamnum: Map.get(event.fields, "team_2")}

            players = List.replace_at(players, player_index, player)
            {teams, players, tmp_events, player_teams}

          "bomb_planted" ->
            [round_start | _] = tmp_events
            start_tick = DemoInfoGo.GameEvent.get_tick(round_start)
            current_tick = DemoInfoGo.GameEvent.get_tick(event)
            tick_difference = current_tick - start_tick
            time_elapsed = tick_difference / tick_rate
            time_left_in_round = @round_time - time_elapsed

            fields =
              Map.get(event, :fields) |> Map.put("time_elapsed", time_elapsed)
              |> Map.put("time_left_in_round", time_left_in_round)

            event = Map.put(event, :fields, fields)

            {_, id} = DemoInfoGo.GameEvent.process_player_field(event)
            player = Enum.find(players, fn p -> p.id == id end)
            team_index = Enum.find_index(teams, fn t -> t.teamnum == player.teamnum end)
            team = Enum.at(teams, team_index)
            team = %{team | bomb_plants: [event | team.bomb_plants]}
            teams = List.replace_at(teams, team_index, team)
            tmp_events = [event | tmp_events]
            {teams, players, tmp_events, player_teams}

          "bomb_defused" ->
            [bomb_planted | _] = tmp_events
            start_tick = DemoInfoGo.GameEvent.get_tick(bomb_planted)
            current_tick = DemoInfoGo.GameEvent.get_tick(event)
            tick_difference = current_tick - start_tick
            time_elapsed = tick_difference / tick_rate
            time_left = @bomb_timer - time_elapsed

            fields =
              Map.get(event, :fields) |> Map.put("time_elapsed", time_elapsed)
              |> Map.put("time_left", time_left)

            event = Map.put(event, :fields, fields)

            {_, id} = DemoInfoGo.GameEvent.process_player_field(event)
            player = Enum.find(players, fn p -> p.id == id end)
            team_index = Enum.find_index(teams, fn t -> t.teamnum == player.teamnum end)
            team = Enum.at(teams, team_index)
            team = %{team | bomb_defusals: [event | team.bomb_defusals]}
            teams = List.replace_at(teams, team_index, team)
            {teams, players, tmp_events, player_teams}

          "round_end" ->
            winner = DemoInfoGo.GameEvent.get_winner(event)
            [team1, team2] = teams

            {winner, loser} =
              cond do
                team1.teamnum == winner ->
                  {team1, team2}

                true ->
                  {team2, team1}
              end

            winner = %{
              winner
              | round_wins: [event | winner.round_wins],
                rounds_won: winner.rounds_won + 1
            }

            loser = %{
              loser
              | round_losses: [event | loser.round_losses],
                rounds_lost: loser.rounds_lost + 1
            }

            teams = [winner, loser]
            {teams, players, tmp_events, player_teams}

          _ ->
            {teams, players, tmp_events, player_teams}
        end
      end)

    {teams, players}
  end
end
