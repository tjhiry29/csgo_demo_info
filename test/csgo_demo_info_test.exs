defmodule DemoinfogoTest do
  use ExUnit.Case

  test "correctly finds trade kills" do
    first_kill = %DemoInfoGo.Kill{
      tick: 0,
      attacker_name: "test1",
      victim_name: "test2",
      trade: false
    }

    second_kill = %DemoInfoGo.Kill{
      tick: 5 * 128 - 1,
      attacker_name: "test3",
      victim_name: "test1",
      trade: false
    }

    kill = DemoInfoGo.Kill.find_trades(second_kill, 128, [first_kill])
    assert kill.trade == true
  end

  test "correctly assigns first kill" do
    kills = [%DemoInfoGo.Kill{}, %DemoInfoGo.Kill{}]
    kills = DemoInfoGo.Kill.find_first_kills(kills)
    assert Enum.at(kills, 0).first_of_round == true
  end
end
