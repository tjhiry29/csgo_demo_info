defmodule CSVParser do

  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"

  def parse_deaths_csv(file_name) do
    if File.exists?("results/#{file_name}.csv") do
      # parse csv
      stream = File.stream!("results/#{file_name}.csv")
      {server_info, csv_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      
      {_, result} = csv_stream |> Enum.map(&String.trim_trailing(&1, "\n")) |> Enum.map_reduce([[], []], &parse_csv_line(&1, &2))
      [kills, players] = result
      players = players 
              |> List.flatten() 
              |> Enum.uniq() 
              |> Enum.filter(fn(x) -> x != nil end)
              |> Enum.map(&find_kills(&1, kills))
              |> Enum.map(&find_deaths(&1, kills))
              |> Enum.map(&find_assists(&1, kills))
              |> Enum.sort(fn(player1, player2) -> player1.id < player2.id end)
      IO.inspect players
    else
      IO.puts "No such file results/#{file_name}.csv, please check the directory or ensure the demo dump goes through as expected"
    end
  end

  def parse_game_events(file_name) do
    if File.exists?("results/#{file_name}.dump") do
      # parse dump file
    else
      IO.puts "No such file results/#{file_name}.dump, please check the directory or ensure the demo dump goes through as expected"
    end
  end

  defp parse_csv_line(line, acc) do
    player_info = get_player_info(line)
    kill_info = get_kill_info(line)
    kills = acc |> Enum.at(0) |> List.insert_at(-1, kill_info)
    players = acc |> Enum.at(1) |> List.insert_at(-1, player_info)
    {nil ,[kills, players]} # returns this for map_reduce function.
  end

  defp get_tick_rate(server_info) do
    tick_rate_chunk = server_info 
                      |> Enum.filter(fn(e) ->
                        e |> String.split(" ") |> Enum.at(0) == @tick_interval_key
                      end)

    tick_rate = tick_rate_chunk 
                |> Enum.at(0) 
                |> String.split(" ") 
                |> Enum.at(1) 
                |> String.trim_trailing("\n") 
                |> String.to_float()

    tick_rate
  end

  defp get_player_info(line) do
    fields = String.split(line, ", ")
    victim_fields = Enum.slice(fields, 0, 9)
    attacker_fields = Enum.slice(fields, 9, 9)

    assister_fields = if (Enum.count(fields) == 31) do
      Enum.slice(fields, 20, 9)
    end

    victim = get_player_info_from_fields(victim_fields)
    attacker = get_player_info_from_fields(attacker_fields)
    assister = if (assister_fields != nil) do
      get_player_info_from_fields(assister_fields)
    end

    [victim, attacker, assister]
  end

  defp get_player_info_from_fields(fields) do
    name = Enum.at(fields, 1)
    id = Enum.at(fields, 2) |> String.to_integer()
    player = %Player{name: name, id: id}
    player
  end

  defp get_kill_info(line) do
    fields = String.split(line, ", ")
    [victim, attacker, assister] = get_player_info(line)
    [round, tick] = Enum.take(fields, -2)
    weapon = Enum.at(fields, 18)
    headshot = Enum.at(fields, 19)
    round = String.to_integer(round)
    tick = String.to_integer(tick)
    headshot = String.to_existing_atom(headshot)
    kill = %Kill{attacker_name: attacker.name, victim_name: victim.name, weapon: weapon, round: round, tick: tick, headshot: headshot}
    assist = if (assister != nil) do
        get_assist_info(kill, assister)
    end

    kill = if (assist != nil) do
      %{kill | assist: assist}
    else
      kill
    end
    kill
  end

  defp get_assist_info(kill, assister) do
    %Assist{victim_name: kill.victim_name, assister_name: assister.name, round: kill.round, tick: kill.tick}
  end

  defp find_kills(player, kills) do
    player_kills = kills |> Enum.filter(fn(kill) -> kill.attacker_name == player.name end)
    player = %{player | kills: player_kills}
    player
  end

  defp find_deaths(player, kills) do
    player_deaths = kills |> Enum.filter(fn(kill) -> kill.victim_name == player.name end)
    player = %{player | deaths: player_deaths}
    player
  end

  defp find_assists(player, kills) do
    player_assists = kills |> Enum.reduce([], fn(kill, acc) ->
      acc = if (kill.assist != nil && kill.assist.assister_name == player.name) do
        List.insert_at(acc, -1, kill.assist)
      else
        acc
      end
    end)
    player = %{player | assists: player_assists}
    player
  end
end
