defmodule Mix.Tasks.DemoInfoGoTask.Parse do
  use Mix.Task

  # This module runs demoinfogo.exe and provides the interface with the file name to use
  # The demo should be placed in demoinfogo
  # The results will appear in results with the same filename but a different extension based on the type of parsing performed

  def run(args) do
    filter_options = fn arg ->
      arg == "-deathscsv" || arg == "-gameevents" || arg == "-skipparse"
    end

    filter_args = fn arg -> arg != "-deathscsv" && arg != "-gameevents" && arg != "-skipparse" end
    options = Enum.filter(args, filter_options)
    new_args = Enum.filter(args, filter_args)

    if Enum.empty?(options) do
      IO.puts("no options passed.")
    else
      parse = fn x -> DemoInfoGo.parse_demo(x, options) end

      if !Enum.any?(options, fn str -> str == "-skipparse" end) do
        new_args
        |> OptionParser.parse()
        |> elem(1)
        |> Enum.each(parse)
      end

      # Here we should try to parse the results from game events and deaths_csv
      # we should try to format game events as an object and deaths_csv and put them into a Map of some sort.
      parse_results = fn x -> DemoInfoGo.parse_results(x, options) end
      IO.puts("Now attempting to parse results.")

      new_args
      |> OptionParser.parse()
      |> elem(1)
      |> Enum.each(parse_results)
    end
  end
end
