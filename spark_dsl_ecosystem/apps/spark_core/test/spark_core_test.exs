defmodule SparkCoreTest do
  use ExUnit.Case
  doctest SparkCore

  test "greets the world" do
    assert SparkCore.hello() == :world
  end
end
