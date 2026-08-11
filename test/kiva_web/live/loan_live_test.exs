defmodule KivaWeb.LoanLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  describe "provenance section" do
    test "admin sees the authenticity timeline (lazily fabricated)", %{conn: conn} do
      %{loan: loan} = loan_fixture()

      {:ok, admin} =
        Kiva.Accounts.register_user(%{
          email: "prov-admin-#{System.unique_integer([:positive])}@kredo.test",
          password: "password",
          role: "admin"
        })

      conn = log_in(conn, admin)
      {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")

      assert html =~ "staff view"
      assert html =~ "Hash chain verified"
      assert html =~ "Listing submitted"
      assert html =~ "Story written"
    end

    test "lenders and visitors never see the provenance section", %{conn: conn} do
      %{loan: loan} = loan_fixture()

      {:ok, lender} =
        Kiva.Accounts.register_user(%{
          email: "prov-lender-#{System.unique_integer([:positive])}@kredo.test",
          password: "password",
          role: "lender"
        })

      {:ok, _view, html} = live(log_in(conn, lender), ~p"/loans/#{loan.slug}")
      refute html =~ "staff view"
      refute html =~ "Hash chain verified"

      {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
      refute html =~ "staff view"
    end
  end

  setup do
    %{loan: loan_fixture().loan}
  end

  test "browse lists localized loan cards", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/loans")
    assert html =~ "Weaving loan"
    assert html =~ "Guatemala"
  end

  test "browse cards surface a Lend affordance", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/loans")
    assert html =~ "Lend"
  end

  test "an anonymous visitor sees a Lend call-to-action on a loan", %{conn: conn, loan: loan} do
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "Sign in as a lender to lend"
    refute html =~ "Add to basket"
  end

  test "a lender sees the real lend form (basket + lend now)", %{conn: conn, loan: loan} do
    {:ok, lender} =
      Kiva.Accounts.register_user(%{
        email: "lcta@kredo.test",
        password: "password",
        role: "lender"
      })

    conn = log_in(conn, lender)
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "Add to basket"
    assert html =~ "Lend now"
  end

  test "search narrows the list", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/loans")
    html = view |> element("form[phx-change='search']") |> render_change(%{"q" => "spaceship"})
    assert html =~ "No loans match"
  end

  test "loan profile renders es content when locale is es", %{conn: conn, loan: loan} do
    conn = init_test_session(conn, %{locale: "es"})
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "Préstamo de tejido"
    assert html =~ "Rosa teje"
  end

  test "loan profile in de falls back to en with a badge", %{conn: conn, loan: loan} do
    conn = init_test_session(conn, %{locale: "de"})
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "Weaving loan"
    assert html =~ "EN"
  end

  test "a partner/staff can post a field update visible on the loan", %{conn: conn} do
    # Field updates exist only after fundraising, so use a repaying loan.
    loan = loan_fixture(%{status: "repaying"}).loan

    {:ok, staff} =
      Kiva.Accounts.register_user(%{email: "us@kredo.test", password: "password", role: "staff"})

    conn = log_in(conn, staff)
    {:ok, view, _} = live(conn, ~p"/loans/#{loan.slug}")

    html =
      view
      |> form("form[phx-submit='post_update']", %{kind: "update", body: "Field progress here"})
      |> render_submit()

    assert html =~ "Field progress here"
  end

  test "lend now requires a confirm step, then celebrates", %{conn: conn, loan: loan} do
    {:ok, lender} =
      Kiva.Accounts.register_user(%{
        email: "cel@kredo.test",
        password: "password",
        role: "lender"
      })

    conn = log_in(conn, lender)
    {:ok, view, _} = live(conn, ~p"/loans/#{loan.slug}")

    html =
      view
      |> form("form[phx-submit='lend_action']")
      |> render_submit(%{action: "lend", amount_cents: "5000"})

    assert html =~ "Confirm your lending"
    assert html =~ "no real money moves"

    html2 = view |> element("button[phx-click='confirm_lend']") |> render_click()
    assert html2 =~ "You moved"
    assert html2 =~ "Thank you for lending"
  end

  test "loan profile shows social proof (lenders) and urgency (days left)", %{
    conn: conn,
    loan: loan
  } do
    {:ok, lender} =
      Kiva.Accounts.register_user(%{email: "sp@kredo.test", password: "password", role: "lender"})

    Kiva.Portfolio.lend(lender, loan.id, 2500)

    ends = DateTime.utc_now() |> DateTime.add(10 * 86_400, :second) |> DateTime.truncate(:second)

    Kiva.Repo.get!(Kiva.Lending.Loan, loan.id)
    |> Ecto.Changeset.change(fundraising_ends_at: ends)
    |> Kiva.Repo.update!()

    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "lenders"
    assert html =~ "days left"
  end

  test "loan profile shows trust & verification with attestation", %{conn: conn, loan: loan} do
    trustee = Kiva.Trust.upsert_trustee("tr2", "US", %{"en" => {"Maria Trustee", "bio"}})

    Kiva.Trust.add_endorsement(loan.id, trustee.id, loan.borrower_id, "en", %{
      "en" => "She is reliable"
    })

    Kiva.Trust.attest(loan.id, "x")

    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")
    assert html =~ "Trust &amp; verification"
    assert html =~ "Maria Trustee"
    assert html =~ "verified"
  end
end
