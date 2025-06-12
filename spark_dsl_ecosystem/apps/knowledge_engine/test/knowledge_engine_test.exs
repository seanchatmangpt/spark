defmodule KnowledgeEngineTest do
  use ExUnit.Case
  doctest KnowledgeEngine

  test "greets the world" do
    assert KnowledgeEngine.hello() == :world
  end
end
