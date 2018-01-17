defmodule Kill do
	defstruct [:attacker_name, :victim_name, :weapon, :round, :tick, :headshot, trade: false, assist: nil]
end