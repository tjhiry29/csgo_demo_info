defmodule ResultsParser do
  def parse_deaths_csv(file_name) do
    if File.exists?("results/#{file_name}.csv") do
      parse_csv_line = fn(line) ->
        player_info = get_player_info(line)
        assist_info = get_assist_info(line)
        kill_info = get_kill_info(line)
        {kill_info, assist_info, player_info}
      end

      reduce_tuple_to_list = fn(e, acc) ->
        first = Enum.at(acc, 0) |> List.insert_at(-1, elem(e, 0))
        second = Enum.at(acc, 1) |> List.insert_at(-1, elem(e, 1))
        third = Enum.at(acc, 2) |> List.insert_at(-1, elem(e, 2))
        acc = [first, second, third]
        acc
      end

      # parse csv
      [kills, assists, players] = "results/#{file_name}.csv"
                                  |> File.stream!()
                                  |> Enum.map(parse_csv_line)
                                  |> Enum.reduce([[], [], []], reduce_tuple_to_list)

      IO.inspect kills
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
