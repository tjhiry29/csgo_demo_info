defmodule ResultsParser do

  @num_server_info_lines 19

  def parse_deaths_csv(file_name) do
    if File.exists?("results/#{file_name}.csv") do
      reduce_tuple_to_list = fn(e, acc) ->
        kills = acc |> Enum.at(0) |> List.insert_at(-1, elem(e, 0))
        assists = acc |> Enum.at(1) |> List.insert_at(-1, elem(e, 1))
        players = acc |> Enum.at(2) |> List.insert_at(-1, elem(e, 2))
        acc = [kills, assists, players]
        acc
      end

      # parse csv
      stream = File.stream!("results/#{file_name}.csv")
      {server_info, csv_stream} = Enum.split(stream, @num_server_info_lines)
      tick_rate = get_tick_rate(server_info)
      
      [kills, assists, players] = csv_stream
                                  |> Enum.map(&parse_csv_line(&1))
                                  |> Enum.reduce([[], [], []], reduce_tuple_to_list)

      [kills, assists, players]
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

  defp parse_csv_line(line) do
    player_info = get_player_info(line)
    assist_info = get_assist_info(line)
    kill_info = get_kill_info(line)
    {kill_info, assist_info, player_info}
  end

  defp get_tick_rate(server_info) do
    tick_rate_chunk = server_info |> Enum.filter(fn(e) ->
        e |> String.split(" ") |> Enum.at(0) == "tick_interval:"
      end)
    tick_rate = tick_rate_chunk |> Enum.at(0) |> String.split(" ") |> Enum.at(1)
    tick_rate
  end

  defp get_player_info(line) do
    line
  end

  defp get_assist_info(line) do
    line
  end

  defp get_kill_info(line) do
    line
  end
end
