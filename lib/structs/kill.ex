defmodule Kill do
	defstruct [:killer_name, :victim_name, :weapon, :round_num, :tick, head_shot: false, trade: false]
end