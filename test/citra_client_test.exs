defmodule CitraClientTest do
  use ExUnit.Case
  doctest CitraClient

  test "greets the world" do
    assert CitraClient.hello() == :world
  end
end
