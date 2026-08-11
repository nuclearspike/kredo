defmodule Kiva.TranslationTest do
  use ExUnit.Case, async: true

  alias Kiva.Translation

  test "machine_translate tags direction and applies glossary" do
    out = Translation.machine_translate("This loan helps a borrower", "en", "es")
    assert out =~ "[es←en]"
    assert out =~ "préstamo"
    assert out =~ "prestatario"
  end

  test "machine_translate is a no-op marker for nil/empty" do
    assert Translation.machine_translate(nil, "en", "de") == nil
    assert Translation.machine_translate("", "en", "de") == ""
  end

  test "source_hash is stable and content-sensitive" do
    a = Translation.source_hash("hello")
    assert a == Translation.source_hash("hello")
    assert a != Translation.source_hash("hellp")
  end
end
