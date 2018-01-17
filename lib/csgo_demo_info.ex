defmodule DemoInfoGo do
  @moduledoc """
  Documentation for DemoInfoGo.
  This module is an interface for parsing the demos using demoinfogo.exe
  """

  # parse resulting csv
  # parse resulting dump file
  def parse_results(file_name, types) do
    match_type = fn
      "-deathscsv" -> CSVParser.parse_deaths_csv(file_name)
      # "-gameevents" -> ResultsParser.parse_game_events(file_name)
      _ -> IO.puts "Error: invalid type"
    end

    Enum.each(types, match_type)
  end

  def parse_demo(file_name, types) do
    match_type = fn
      "-deathscsv" -> deaths_csv(file_name)
      "-gameevents" -> game_events(file_name)
      _ -> IO.puts "Error: invalid type"
    end

    Enum.each(types, match_type)
  end

  defp game_events(file_name) do
    cond do
      File.exists?("results/#{file_name}.dump") ->
        IO.puts "Please see the results directory for the following file #{file_name}.dump"

      File.exists?("demoinfogo/#{file_name}.dem") ->
        IO.puts "Starting game events dump"
        File.touch!("results/#{file_name}.dump")

        game_events_command(file_name)

        IO.puts "Please see the results directory for the following file #{file_name}.dump"

      true ->
        IO.puts "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
    end
  end

  defp deaths_csv(file_name) do
    cond do
      File.exists?("results/#{file_name}.csv") ->
        IO.puts "Please see the results directory for the following file #{file_name}.csv"

      File.exists?("demoinfogo/#{file_name}.dem") ->
        IO.puts "Starting deaths csv dump"
        File.touch!("results/#{file_name}.csv")

        deaths_csv_command(file_name)
        
        IO.puts "Please see the results directory for the following file #{file_name}.csv"

      true ->
        IO.puts "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
    end
  end

  defp deaths_csv_command(file_name) do
    cond do
      File.exists?("demoinfogo/demoinfogo.exe") ->
        System.cmd "./demoinfogo/demoinfogo.exe", ["-deathscsv", "-nowarmup", "demoinfogo/#{file_name}.dem"], 
          into: File.stream!("results/#{file_name}.csv", [], :line)

      File.exists?("demoinfogo/demoinfogo") ->
        System.cmd "./demoinfogo/demoinfogo", ["-deathscsv", "-nowarmup", "demoinfogo/#{file_name}.dem"], 
          into: File.stream!("results/#{file_name}.csv", [], :line)          

      true -> IO.puts "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
    end
  end

  defp game_events_command(file_name) do
    cond do
      File.exists?("demoinfogo/demoinfogo.exe") ->
        System.cmd "./demoinfogo/demoinfogo.exe", ["-gameevents", "-extrainfo", "-nofootsteps", "demoinfogo/#{file_name}.dem"], into: File.stream!("results/#{file_name}.dump", [], :line)
      File.exists?("demoinfogo/demoinfogo") ->
        System.cmd "./demoinfogo/demoinfogo", ["-gameevents", "-extrainfo", "-nofootsteps", "demoinfogo/#{file_name}.dem"], into: File.stream!("results/#{file_name}.dump", [], :line)
      true -> IO.puts "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
    end
  end
end
