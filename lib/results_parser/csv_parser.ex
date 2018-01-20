defmodule CSVParser do
  @moduledoc """
  Documentation for CSVParser.
  This module parses the csvs dumped by the -deathscsv command.
  The data has a header containing the map name as well as the tick rate.
  Expected data arrives as such. victim(player), attacker(player), assister(player:optional) and then weapon, headshot, round and tick
  Player fields consist of kill_participant(victim, attacker, assister), name, id, posx, posy, posz, aimx, aimy, side (T || CT)
  Only the name and id are saved for now.

  This module first parses the data to receive all kills and players. Also maps assists to kills.
  Then finds first kills of each round and finds trade kills
  Then maps the kills onto each player.
  """

  # 5 seconds in the past
  @trade_time_limit 5
  @num_server_info_lines 19
  @tick_interval_key "tick_interval:"

  def parse_deaths_csv(file_name) do
    if File.exists?("results/#{file_name}.csv") do
      # parse csv
      stream = File.stream!("results/#{file_name}.csv")
      {server_info, csv_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      tick_rate = round(1 / tick_rate)

      result =
        csv_stream
        |> Enum.map(&String.trim_trailing(&1, "\n"))
        |> Enum.reduce([[], []], &parse_csv_line(&1, &2))

      [kills, players] = result

      kills =
        kills
        |> Enum.sort(fn k1, k2 -> k1.tick < k2.tick end)
        |> Enum.group_by(fn k -> k.round end)
        |> Enum.map(fn {_, v} ->
          kill = %{Enum.at(v, 0) | first_of_round: true}
          v |> List.delete_at(0) |> List.insert_at(0, kill)
        end)
        |> List.flatten()

      kills = Enum.map(kills, &find_trades(&1, tick_rate, kills))

      IO.inspect(kills)

      players =
        players
        |> List.flatten()
        |> Enum.uniq()
        |> Enum.filter(fn x -> x != nil end)
        |> Enum.map(&map_kills(&1, kills))
        |> Enum.sort(fn player1, player2 -> player1.id < player2.id end)
    else
      IO.puts("No such file results/#{file_name}.csv, please check the directory 
                or ensure the demo dump goes through as expected")
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

  defp parse_csv_line(line, acc) do
    player_info = get_player_info(line)
    kill_info = get_kill_info(line)
    kills = acc |> Enum.at(0) |> List.insert_at(-1, kill_info)
    players = acc |> Enum.at(1) |> List.insert_at(-1, player_info)
    [kills, players]
  end

  defp get_player_info(line) do
    fields = String.split(line, ", ")
    victim_fields = Enum.slice(fields, 0, 9)
    attacker_fields = Enum.slice(fields, 9, 9)

    assister_fields =
      if Enum.count(fields) == 31 do
        Enum.slice(fields, 18, 9)
      end

    victim = get_player_info_from_fields(victim_fields)
    attacker = get_player_info_from_fields(attacker_fields)

    assister =
      if assister_fields != nil do
        get_player_info_from_fields(assister_fields)
      end

    [victim, attacker, assister]
  end

  defp get_player_info_from_fields(fields) do
    name = Enum.at(fields, 1)
    id = fields |> Enum.at(2) |> String.to_integer()
    %Player{name: name, id: id}
  end

  defp get_player_position(fields) do
    victim_position = fields |> Enum.slice(3, 3) |> Enum.map(&String.to_float(&1))
    attacker_position = fields |> Enum.slice(12, 3) |> Enum.map(&String.to_float(&1))
    [victim_position, attacker_position]
  end

  defp get_kill_info(line) do
    fields = String.split(line, ", ")
    [victim, attacker, assister] = get_player_info(line)
    [victim_position, attacker_position] = get_player_position(fields)
    [weapon, headshot, round, tick] = Enum.take(fields, -4)
    round = String.to_integer(round)
    tick = String.to_integer(tick)
    headshot = String.to_existing_atom(headshot)

    kill = %Kill{
      attacker_name: attacker.name,
      victim_name: victim.name,
      weapon: weapon,
      round: round,
      tick: tick,
      headshot: headshot,
      victim_position: victim_position,
      attacker_position: attacker_position
    }

    if assister != nil do
      assist = get_assist_info(kill, assister)
      %{kill | assist: assist}
    else
      kill
    end
  end

  defp get_assist_info(kill, assister) do
    %Assist{
      victim_name: kill.victim_name,
      assister_name: assister.name,
      round: kill.round,
      tick: kill.tick
    }
  end

  defp find_trades(kill, tick_rate, kills) do
    filtered_kills =
      kills
      |> Enum.filter(fn k ->
        Range.new(k.tick - @trade_time_limit * tick_rate, k.tick)
        |> Enum.member?(kill.tick)
      end)
      |> Enum.filter(fn k ->
        k.attacker_name == kill.victim_name
      end)

    if Enum.at(filtered_kills, 0) != nil do
      %{kill | trade: true}
    else
      kill
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

    %{player | kills: player_kills, assists: player_assists, deaths: player_deaths}
  end
end
