defmodule DemoInfoGo.Team do
  defstruct [
    :teamnum,
    round_wins: [],
    players: [],
    round_losses: [],
    bomb_plants: [],
    bomb_defusals: [],
    rounds_won: 0,
    rounds_lost: 0
  ]
end
