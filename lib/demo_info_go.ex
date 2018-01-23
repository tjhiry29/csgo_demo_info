defmodule DemoInfoGo do
  @moduledoc """
  Documentation for DemoInfoGo.
  This module is an interface for parsing the demos using demoinfogo.exe
  """

  def run() do
    arg = "faze-vs-sk-m1-inferno"
    ResultsParser.DumpParser.parse_game_events(arg)
  end

  # parse resulting csv
  # parse resulting dump file
  def parse_results(file_name, types) do
    match_type = fn
      "-deathscsv" ->
        ResultsParser.CSVParser.parse_deaths_csv(file_name)

      "-gameevents" ->
        ResultsParser.DumpParser.parse_game_events(file_name)

      _ ->
        IO.puts("Error: invalid type")
    end

    Enum.each(types, match_type)
  end

  def parse_demo(file_name, types) do
    match_type = fn
      "-deathscsv" -> deaths_csv(file_name)
      "-gameevents" -> game_events(file_name)
      _ -> IO.puts("Error: invalid type")
    end

    Enum.each(types, match_type)
  end

  defp game_events(file_name) do
    if File.exists?("demoinfogo/#{file_name}.dem") do
      IO.puts("Starting game events dump")
      File.touch!("results/#{file_name}.dump")

      game_events_command(file_name)

      IO.puts("Please see the results directory for the following file #{file_name}.dump")
    else
      IO.puts(
        "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
      )
    end
  end

  defp deaths_csv(file_name) do
    if File.exists?("demoinfogo/#{file_name}.dem") do
      IO.puts("Starting deaths csv dump")
      File.touch!("results/#{file_name}.csv")

      deaths_csv_command(file_name)

      IO.puts("Please see the results directory for the following file #{file_name}.csv")
    else
      IO.puts(
        "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
      )
    end
  end

  defp deaths_csv_command(file_name) do
    cond do
      File.exists?("demoinfogo/demoinfogo.exe") ->
        System.cmd(
          "./demoinfogo/demoinfogo.exe",
          ["-deathscsv", "-nowarmup", "demoinfogo/#{file_name}.dem"],
          into: File.stream!("results/#{file_name}.csv", [], :line)
        )

      File.exists?("demoinfogo/demoinfogo") ->
        System.cmd(
          "./demoinfogo/demoinfogo",
          ["-deathscsv", "-nowarmup", "demoinfogo/#{file_name}.dem"],
          into: File.stream!("results/#{file_name}.csv", [], :line)
        )

      true ->
        IO.puts(
          "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
        )
    end
  end

  defp game_events_command(file_name) do
    cond do
      File.exists?("demoinfogo/demoinfogo.exe") ->
        System.cmd(
          "./demoinfogo/demoinfogo.exe",
          ["-gameevents", "-extrainfo", "-nofootsteps", "demoinfogo/#{file_name}.dem"],
          into: File.stream!("results/#{file_name}.dump", [], :line)
        )

      File.exists?("demoinfogo/demoinfogo") ->
        System.cmd(
          "./demoinfogo/demoinfogo",
          ["-gameevents", "-extrainfo", "-nofootsteps", "demoinfogo/#{file_name}.dem"],
          into: File.stream!("results/#{file_name}.dump", [], :line)
        )

      true ->
        IO.puts(
          "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
        )
    end
  end
end
