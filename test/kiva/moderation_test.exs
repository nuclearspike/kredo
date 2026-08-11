defmodule Kiva.ModerationTest do
  use ExUnit.Case, async: true
  alias Kiva.Moderation

  test "approves kind messages" do
    assert Moderation.moderate("Wishing you a strong season!") == :approved
  end

  test "rejects unkind language" do
    assert {:rejected, _} = Moderation.moderate("you idiot")
  end

  test "rejects solicitation" do
    assert {:rejected, _} = Moderation.moderate("please venmo me some cash")
  end

  test "asks for a rewrite on shouting" do
    assert {:rewrite, _} = Moderation.moderate("THIS IS ALL UPPERCASE SHOUTING")
  end

  test "rejects too-short" do
    assert {:rejected, _} = Moderation.moderate("")
  end
end
