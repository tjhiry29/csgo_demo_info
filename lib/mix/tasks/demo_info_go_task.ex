defmodule Mix.Tasks.DemoInfoGoTask.Parse do
	use Mix.Task

	def run(args) do
		parsed = OptionParser.parse(args)
		parsed_args = elem(parsed, 1)
		Demoinfogo.parse_demo(Enum.at(parsed_args, 0), ["deaths_csv"])
	end
end	