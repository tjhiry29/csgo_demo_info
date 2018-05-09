defmodule DemoInfoGo.Assist do
  defstruct [
    :victim_name,
    :victim_id,
    :assister_name,
    :assister_id,
    :round,
    :tick,
    time_left_in_round: 0,
    time_elapsed: 0
  ]
end
