defmodule SparkDslTestTest do
  use ExUnit.Case
  doctest SparkDslTest

  test "greets the world" do
    assert SparkDslTest.hello() == :world
  end
end
