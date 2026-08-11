defmodule KivaWeb.PartnerLiveTest do
  use KivaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  setup do
    partner_user_fixture()
  end

  test "partner sees borrowers and can start a loan", %{
    conn: conn,
    user: user,
    borrower: borrower
  } do
    conn = log_in(conn, user)
    {:ok, view, html} = live(conn, ~p"/partner")
    assert html =~ "Rosa"

    html =
      view |> element("button[phx-value-borrower-id='#{borrower.id}']") |> render_click()

    assert html =~ "Submit for staff review"
  end

  test "submitting an incomplete draft is blocked by eligibility", %{
    conn: conn,
    user: user,
    borrower: borrower
  } do
    conn = log_in(conn, user)
    {:ok, view, _} = live(conn, ~p"/partner")
    view |> element("button[phx-value-borrower-id='#{borrower.id}']") |> render_click()
    html = view |> element("button[phx-click='submit_review']") |> render_click()
    assert html =~ "Not ready to submit"
  end

  test "a partner can onboard a new borrower", %{conn: conn, user: user} do
    conn = log_in(conn, user)
    {:ok, view, _} = live(conn, ~p"/partner")

    view
    |> form("#new-borrower-form", borrower: %{name: "Brand New Borrower", country_code: "GT"})
    |> render_submit()

    assert render(view) =~ "Brand New Borrower"
  end

  test "a partner sees the changes-requested reason and can resume", %{conn: conn} do
    base = submitted_loan_fixture()
    Kiva.Lending.request_changes(base.draft.id, "Please add the borrower photo")

    conn = log_in(conn, base.user)
    {:ok, _view, html} = live(conn, ~p"/partner")
    assert html =~ "Please add the borrower photo"
    assert html =~ "Address changes"
  end

  test "partner dashboard shows stats and repayments due", %{conn: conn, user: user, loan: loan} do
    # Repayments are only due once the loan is past fundraising.
    loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    conn = log_in(conn, user)
    {:ok, _view, html} = live(conn, ~p"/partner")
    assert html =~ "Active loans"
    assert html =~ "Repayments due"
  end

  test "the repayments-due page lists and searches", %{conn: conn, user: user, loan: loan} do
    loan |> Ecto.Changeset.change(status: "repaying") |> Kiva.Repo.update!()

    conn = log_in(conn, user)
    {:ok, view, html} = live(conn, ~p"/partner/repayments")
    assert html =~ "Record repayment"

    # search matching the fixture borrower "Rosa"
    assert view |> form("form[phx-change='search']", %{q: "Rosa"}) |> render_change() =~
             "Record repayment"

    # search matching nothing hides the row
    refute view |> form("form[phx-change='search']", %{q: "zzznope"}) |> render_change() =~
             "Record repayment"
  end

  test "non-partner cannot reach the workspace", %{conn: conn} do
    conn = log_in(conn, user_fixture(%{role: "lender"}))
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/partner")
  end
end
