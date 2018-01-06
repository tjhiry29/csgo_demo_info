defmodule Demoinfogo do
  @moduledoc """
  Documentation for Demoinfogo.
  """
  def start(_type, args) do
    parsed = OptionParser.parse(args)
    deaths_csv(parsed[:args])
  end

  def start_demo_info_go do
    System.cmd "./demoinfogo/demoinfogo.exe", ["-deathscsv", "-nowarmup", "demoinfogo/faze-vs-sk-m1-inferno.dem"], into: IO.stream(:stdio, :line)
  end

  def parse_demo(file_name, types) do
    match_type = fn
      "deaths_csv" -> deaths_csv(file_name)
      "game_events" -> game_events(file_name)
      _ -> IO.puts "Error invalid type"
    end
    Enum.each(types, match_type)
  end

  defp game_events(file_name) do
    File.touch!("results/#{file_name}.dump")
    if File.exists?("demoinfogo/#{file_name}.dem") do
      game_events_command(file_name)
      IO.puts "Please see the results directory for the following files #{file_name}.dump"
    else
      IO.puts "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
    end
  end

  defp deaths_csv(file_name) do
    File.touch!("results/#{file_name}.csv")
    if File.exists?("demoinfogo/#{file_name}.dem") do
      deaths_csv_command(file_name)
      IO.puts "Please see the results directory for the following files #{file_name}.csv"
    else
      IO.puts "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
    end
  end

  defp deaths_csv_command(file_name) do
      System.cmd "./demoinfogo/demoinfogo.exe", ["-deathscsv", "-nowarmup", "demoinfogo/#{file_name}.dem"], into: File.stream!("results/#{file_name}.csv", [], :line)    
  end

  defp game_events_command(file_name) do
      System.cmd "./demoinfogo/demoinfogo.exe", ["-gameevents", "-extrainfo", "-nofootsteps", "demoinfogo/#{file_name}.dem"], into: File.stream!("results/#{file_name}.dump", [], :line)    
  end
end
