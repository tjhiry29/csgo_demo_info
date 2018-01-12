defmodule ResultsParser do
  def parse_deaths_csv(file_name) do
    if File.exists?("results/#{file_name}.csv") do
      # parse csv
      "results/#{file_name}.csv"
      |> File.stream!()
      |> Stream.each(&parse_csv_line(&1))
      |> Stream.run
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
  
  def parse_csv_line(line) do
    
    IO.puts line
  end
end
