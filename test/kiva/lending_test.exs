defmodule Kiva.LendingStageTest do
  # A fundraising loan has no repayments due yet — the partner overview must
  # not list it in `repayments_due`.
  use Kiva.DataCase, async: true
  import Kiva.LendingFixtures

  # Typing toward "catering" passes through "cat", which is a substring of
  # "education" — a plain ILIKE '%cat%' therefore surfaced education loans to
  # someone searching for caterers. Search matches word beginnings instead.
  test "search matches word beginnings, not substrings buried in other words" do
    catering = search_loan_fixture("Ingredients for her catering", "Fulfils catering orders.")
    education = search_loan_fixture("Books for Amina's future", "Support education essentials.")

    slugs = fn q ->
      "en"
      |> Kiva.Lending.list_localized_loans(%{status: "fundraising", q: q})
      |> Enum.map(& &1.loan.slug)
    end

    assert catering.slug in slugs.("catering")
    refute education.slug in slugs.("catering")

    # "cat" begins the word "catering" but is buried inside "education".
    assert catering.slug in slugs.("cat")
    refute education.slug in slugs.("cat")

    # A single character matches nearly every loan; it is noise, not a search.
    assert slugs.("c") == slugs.("")
  end

  # Matching every translation surfaced cards whose visible text contained none
  # of the searched words. Search now reads the row the reader is shown.
  test "search reads the language the reader is shown, including the English fallback" do
    bilingual = loan_fixture(%{status: "fundraising"}).loan
    put_lc(bilingual, "en", "Loom repairs", "Fixes her weaving loom.")
    put_lc(bilingual, "es", "Reparacion de telar", "Arregla su telar.")

    # This one's Spanish row is a draft, so a Spanish reader is shown English.
    english_only = loan_fixture(%{status: "fundraising"}).loan
    put_lc(english_only, "en", "Beekeeping starter hives", "Buys her first hives.")
    put_lc(english_only, "es", "Colmenas para apicultura", "Compra colmenas.", "draft")

    slugs = fn locale, q ->
      locale
      |> Kiva.Lending.list_localized_loans(%{status: "fundraising", q: q})
      |> Enum.map(& &1.loan.slug)
    end

    # A word only present in Spanish is invisible to an English reader.
    assert bilingual.slug in slugs.("es", "telar")
    refute bilingual.slug in slugs.("en", "telar")

    # ...and the reverse.
    assert bilingual.slug in slugs.("en", "loom")
    refute bilingual.slug in slugs.("es", "loom")

    # With no usable Spanish row the reader sees English, so English is searched.
    assert english_only.slug in slugs.("es", "beekeeping")
    refute english_only.slug in slugs.("es", "colmenas")

    # Counts are computed the same way, so they agree with the results.
    counts = Kiva.Lending.status_counts("en", %{q: "telar"})
    assert Map.get(counts, "fundraising", 0) == 0
    assert Kiva.Lending.status_counts("es", %{q: "telar"})["fundraising"] == 1
  end

  defp put_lc(loan, locale, title, short_description, status \\ nil) do
    Kiva.Lending.upsert_loan_lc(%{
      loan_id: loan.id,
      locale_code: locale,
      is_source: locale == "en",
      source_locale_code: "en",
      title: title,
      short_description: short_description,
      borrower_story: short_description,
      loan_use: "",
      repayment_summary: "",
      risk_summary_public: "",
      translation_status: status || if(locale == "en", do: "published", else: "approved")
    })
  end

  defp search_loan_fixture(title, short_description) do
    %{loan: loan} = loan_fixture(%{status: "fundraising"})

    for locale <- ~w(en es de fr nl) do
      Kiva.Lending.upsert_loan_lc(%{
        loan_id: loan.id,
        locale_code: locale,
        is_source: locale == "en",
        source_locale_code: "en",
        title: title,
        short_description: short_description,
        borrower_story: short_description,
        loan_use: "",
        repayment_summary: "",
        risk_summary_public: "",
        translation_status: "published"
      })
    end

    loan
  end

  test "schedule items preload date-ordered regardless of physical row order" do
    base = loan_fixture(%{status: "repaying"})
    schedule = Kiva.Repo.preload(base.loan, :repayment_schedule).repayment_schedule

    Kiva.Repo.delete_all(
      from i in Kiva.Lending.RepaymentScheduleItem,
        where: i.repayment_schedule_id == ^schedule.id
    )

    for d <- [~D[2027-01-01], ~D[2026-06-01], ~D[2026-01-01]] do
      Kiva.Repo.insert!(%Kiva.Lending.RepaymentScheduleItem{
        repayment_schedule_id: schedule.id,
        due_on: d,
        amount_cents: 2500,
        status: "scheduled"
      })
    end

    profile = Kiva.Lending.get_localized_loan(base.loan.slug, "en")
    dates = Enum.map(profile.schedule.items, & &1.due_on)
    assert dates == Enum.sort(dates, Date)
  end

  test "repayments due exclude fundraising loans and surface funded ones" do
    base = loan_fixture()

    # Fundraising: nothing due yet.
    assert Kiva.Lending.partner_overview(base.partner.id).repayments_due_count == 0
    assert Kiva.Lending.partner_repayments_due(base.partner.id).rows == []

    base.loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    assert Kiva.Lending.partner_overview(base.partner.id).repayments_due_count == 1

    assert %{rows: [row], total: 1} = Kiva.Lending.partner_repayments_due(base.partner.id)
    assert row.loan.id == base.loan.id
  end
end

defmodule Kiva.LendingTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Lending

  setup do
    %{loan: loan_fixture().loan}
  end

  test "localizes loan cards to es and falls back to en for de", %{loan: loan} do
    [es] = Lending.list_localized_loans("es", %{})
    assert es.title == "Préstamo de tejido"
    refute es.fallback_used

    [de] = Lending.list_localized_loans("de", %{})
    assert de.title == "Weaving loan"
    assert de.fallback_used
    assert de.resolved_locale == "en"
    assert de.sector_name == "Arts"
    _ = loan
  end

  test "funded_percent is computed from cents", %{loan: loan} do
    assert Lending.funded_percent(loan) == 40
  end

  test "filters by sector, country, trust model and text", %{loan: loan} do
    assert [_] = Lending.list_localized_loans("en", %{sector_id: loan.sector_id})
    assert [] = Lending.list_localized_loans("en", %{country_code: "KE"})
    assert [_] = Lending.list_localized_loans("en", %{trust_model: "partner_facilitated"})
    assert [_] = Lending.list_localized_loans("en", %{q: "weaving"})
    assert [] = Lending.list_localized_loans("en", %{q: "spaceship"})
  end

  test "get_localized_loan returns a profile with schedule", %{loan: loan} do
    profile = Lending.get_localized_loan(loan.slug, "en")
    assert profile.borrower_story == "Rosa weaves textiles"
    assert profile.schedule
    assert length(profile.schedule.items) == 8
  end
end
