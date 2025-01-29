defmodule GSheetTest do
  use ExUnit.Case
  doctest GSheet

  test "greets the world" do
    assert GSheet.hello() == :world
  end
end
