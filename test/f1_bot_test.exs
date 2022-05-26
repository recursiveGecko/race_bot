defmodule F1BotTest do
  use ExUnit.Case
  doctest F1Bot

  test "greets the world" do
    assert F1Bot.hello() == :world
  end
end
