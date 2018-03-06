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
  def parse_results(file_name, types, path \\ "") do
    match_type = fn
      "-deathscsv" ->
        ResultsParser.CSVParser.parse_deaths_csv(file_name, path)

      "-gameevents" ->
        ResultsParser.DumpParser.parse_game_events(file_name, path)

      "-skipdump" ->
        nil

      _ ->
        IO.puts("Error: invalid type")
    end

    Enum.map(types, match_type)
  end

  def parse_demo(file_name, types, path \\ "") do
    match_type = fn
      "-deathscsv" -> deaths_csv(file_name, path)
      "-gameevents" -> game_events(file_name, path)
      _ -> IO.puts("Error: invalid type")
    end

    Enum.each(types, match_type)
  end

  defp game_events(file_name, path) do
    if File.exists?("#{path}demoinfogo/#{file_name}.dem") do
      IO.puts("Starting game events dump")
      File.touch!("#{path}results/#{file_name}.dump")

      game_events_command(file_name, path)

      IO.puts("Please see the results directory for the following file #{file_name}.dump")
    else
      IO.puts(
        "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
      )
    end
  end

  defp deaths_csv(file_name, path) do
    if File.exists?("#{path}demoinfogo/#{file_name}.dem") do
      IO.puts("Starting deaths csv dump")
      File.touch!("#{path}results/#{file_name}.csv")

      deaths_csv_command(file_name, path)

      IO.puts("Please see the results directory for the following file #{file_name}.csv")
    else
      IO.puts(
        "ERROR: Could not find file #{file_name}.dem in the demoinfogo directory. Please check the directory again."
      )
    end
  end

  defp deaths_csv_command(file_name, path) do
    cond do
      File.exists?("#{path}demoinfogo/demoinfogo.exe") ->
        System.cmd(
          "./#{path}demoinfogo/demoinfogo.exe",
          ["-deathscsv", "-nowarmup", "#{path}demoinfogo/#{file_name}.dem"],
          into: File.stream!("#{path}results/#{file_name}.csv", [], :line)
        )

      File.exists?("#{path}demoinfogo/demoinfogo") ->
        System.cmd(
          "./#{path}demoinfogo/demoinfogo",
          ["-deathscsv", "-nowarmup", "#{path}demoinfogo/#{file_name}.dem"],
          into: File.stream!("#{path}results/#{file_name}.csv", [], :line)
        )

      true ->
        IO.puts(
          "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
        )
    end
  end

  defp game_events_command(file_name, path) do
    cond do
      File.exists?("#{path}demoinfogo/demoinfogo.exe") ->
        System.cmd(
          "./#{path}demoinfogo/demoinfogo.exe",
          ["-gameevents", "-extrainfo", "-nofootsteps", "#{path}demoinfogo/#{file_name}.dem"],
          into: File.stream!("#{path}results/#{file_name}.dump", [], :line)
        )

      File.exists?("#{path}demoinfogo/demoinfogo") ->
        System.cmd(
          "./#{path}demoinfogo/demoinfogo",
          ["-gameevents", "-extrainfo", "-nofootsteps", "#{path}demoinfogo/#{file_name}.dem"],
          into: File.stream!("#{path}results/#{file_name}.dump", [], :line)
        )

      true ->
        IO.puts(
          "Error, could not find demoinfogo.exe or demoinfogo please check the demoinfogo directory and ensure that the program is there."
        )
    end
  end
end
