defmodule PlayerRoundRecord do
  defstruct [
    :name,
    :id,
    :team,
    :round,
    assists: [],
    damage_dealt: 0,
    dead: false,
    flash_assists: 0,
    grenade_throws: [],
    kills: [],
    traded: false
  ]
end
