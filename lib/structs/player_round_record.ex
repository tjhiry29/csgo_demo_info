defmodule PlayerRoundRecord do
  defstruct [
    :name,
    :id,
    :team,
    :round,
    assists: [],
    damage_dealt: %{},
    dead: false,
    death: nil,
    flash_assists: 0,
    grenade_throws: [],
    health: 100,
    kills: [],
    traded: false
  ]
end
