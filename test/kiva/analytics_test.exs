defmodule Kiva.AnalyticsTest do
  @moduledoc "A5 — admin distribution analytics aggregates."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Analytics

  test "overview aggregates loans by status, country, sector funding, and translation coverage" do
    loan_fixture()
    o = Analytics.overview("en")

    assert is_list(o.by_status)
    assert Enum.any?(o.by_status, fn {_status, n} -> n >= 1 end)

    assert is_list(o.by_country)
    assert Enum.any?(o.by_country, fn {country, n} -> is_binary(country) and n >= 1 end)

    assert is_list(o.by_sector)
    assert Enum.any?(o.by_sector, fn {name, cents} -> is_binary(name) and is_integer(cents) end)

    assert Enum.any?(o.translation_coverage, fn {loc, n} -> loc == "en" and n >= 1 end)
    assert is_list(o.ai_usage)
  end
end
