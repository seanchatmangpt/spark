defmodule DslSynthesizerTest do
  use ExUnit.Case
  doctest DslSynthesizer

  test "greets the world" do
    assert DslSynthesizer.hello() == :world
  end
end
