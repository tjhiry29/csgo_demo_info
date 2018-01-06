defmodule DemoinfogoTest do
  use ExUnit.Case
  doctest Demoinfogo

  test "greets the world" do
    assert Demoinfogo.hello() == :world
  end
end
