defmodule KivaWeb.LoanStageDisplayTest do
  # Loan surfaces only show lifecycle data relevant to the loan's stage:
  # fundraising loans show funding progress (never repayment or field updates);
  # post-fundraising loans show repayment progress (never funding progress or
  # days-left). Funding bars render `progress-primary`; repayment bars render
  # `progress-success`.
  use KivaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Kiva.LendingFixtures

  defp future(days),
    do: DateTime.utc_now() |> DateTime.add(days * 86_400, :second) |> DateTime.truncate(:second)

  test "fundraising loan page shows funding progress but no repayment or field updates", %{
    conn: conn
  } do
    loan = loan_fixture().loan
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")

    assert html =~ "progress-primary"
    refute html =~ "Repaid:"
    refute html =~ "Updates from the field"
  end

  test "post-fundraising loan page shows repayment progress but no funding progress or days left",
       %{conn: conn} do
    loan = loan_fixture(%{status: "repaying", fundraising_ends_at: future(30)}).loan
    {:ok, _view, html} = live(conn, ~p"/loans/#{loan.slug}")

    assert html =~ "Repaid:"
    assert html =~ "Updates from the field"
    refute html =~ "progress-primary"
    refute html =~ "days left"
  end

  test "drawer shows funding progress only while fundraising", %{conn: conn} do
    live_loan = loan_fixture().loan
    done_loan = loan_fixture(%{status: "repaying", fundraising_ends_at: future(30)}).loan

    {:ok, view, _} = live(conn, ~p"/loans")

    # Assert inside the drawer only — the browse grid behind it legitimately
    # shows funding bars for its fundraising cards.
    render_click(view, "open_drawer", %{"slug" => live_loan.slug})
    assert view |> element("#loan-drawer") |> render() =~ "progress-primary"

    render_click(view, "open_drawer", %{"slug" => done_loan.slug})
    drawer = view |> element("#loan-drawer") |> render()
    refute drawer =~ "progress-primary"
    assert drawer =~ "progress-success"
  end

  test "borrower portal shows repayment progress, not a funding bar, for a repaying loan", %{
    conn: conn
  } do
    base = borrower_user_fixture()

    base.loan
    |> Ecto.Changeset.change(status: "repaying")
    |> Kiva.Repo.update!()

    {:ok, _view, html} = live(log_in(conn, base.user), ~p"/portal")

    refute html =~ "progress-primary"
    assert html =~ "progress-success"
  end
end
