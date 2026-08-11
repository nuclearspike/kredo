defmodule Kiva.LocalizationTest do
  use Kiva.DataCase, async: true

  alias Kiva.Localization
  alias Kiva.Localization.Locale

  describe "locale support" do
    test "supported? / normalize" do
      assert Localization.supported?("es")
      refute Localization.supported?("xx")
      assert Localization.normalize("fr") == "fr"
      assert Localization.normalize("xx") == "en"
      assert Localization.normalize(nil) == "en"
    end
  end

  describe "fallback_chain/1" do
    test "english resolves to just itself" do
      assert Localization.fallback_chain("en") == ["en"]
    end

    test "other locales fall back to english" do
      assert Localization.fallback_chain("es") == ["es", "en"]
      assert Localization.fallback_chain("nl") == ["nl", "en"]
    end

    test "unknown locale falls back to english only" do
      assert Localization.fallback_chain("xx") == ["en"]
    end
  end

  describe "format_money/3 — numeric truth localized only at presentation" do
    test "english uses comma thousands, dollar prefix; whole dollars omit cents" do
      assert Localization.format_money(100_000, "USD", "en") == "$1,000"
      assert Localization.format_money(95_000, "USD", "en") == "$950"
    end

    test "cents are shown only for non-whole-dollar amounts (e.g. repayments)" do
      assert Localization.format_money(11_875, "USD", "en") == "$118.75"
      assert Localization.format_money(11_875, "USD", "de") == "118,75 $"
    end

    test "european locales use dot thousands, comma decimal, trailing symbol" do
      assert Localization.format_money(100_000, "USD", "de") == "1.000 $"
      assert Localization.format_money(120_000, "EUR", "fr") == "1.200 €"
    end
  end

  describe "list_locales/0" do
    test "returns enabled locales ordered by code" do
      for {code, name} <- [{"en", "English"}, {"es", "Español"}] do
        Repo.insert!(%Locale{code: code, english_name: name, native_name: name})
      end

      codes = Localization.list_locales() |> Enum.map(& &1.code)
      assert codes == ["en", "es"]
    end
  end
end
