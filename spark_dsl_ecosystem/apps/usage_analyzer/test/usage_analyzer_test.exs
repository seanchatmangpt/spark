defmodule UsageAnalyzerTest do
  use ExUnit.Case
  doctest UsageAnalyzer

  test "greets the world" do
    assert UsageAnalyzer.hello() == :world
  end
end
