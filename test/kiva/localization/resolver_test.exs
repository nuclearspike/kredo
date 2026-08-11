defmodule Kiva.Localization.ResolverTest do
  use ExUnit.Case, async: true

  alias Kiva.Localization.Resolver

  defp rows(codes), do: Enum.map(codes, &%{locale_code: &1, translation_status: "published"})

  test "returns the requested locale when present" do
    res = Resolver.resolve(rows(["en", "es"]), "es")
    assert res.locale == "es"
    refute res.fallback_used
    refute res.missing
  end

  test "falls back to english when requested locale absent" do
    res = Resolver.resolve(rows(["en", "fr"]), "de")
    assert res.locale == "en"
    assert res.fallback_used
    refute res.missing
  end

  test "reports missing when no row resolves" do
    res = Resolver.resolve([], "de")
    assert res.missing
    assert res.fallback_used
    assert is_nil(res.row)
  end

  test "unknown requested locale resolves through en" do
    res = Resolver.resolve(rows(["en"]), "xx")
    assert res.locale == "en"
  end
end
