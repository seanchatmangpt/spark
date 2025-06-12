defmodule AgiFactoryTest do
  use ExUnit.Case
  doctest AgiFactory

  test "greets the world" do
    assert AgiFactory.hello() == :world
  end
end
