defmodule CabuetaTest do
  use ExUnit.Case

  doctest Cabueta

  test "greets the world" do
    assert Cabueta.hello() == :world
  end

  test "parses all tools" do
    Main.test_tools()
  end
end
