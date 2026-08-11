defmodule KivaWeb.KivaGraphql.SchemaTest do
  @moduledoc "Parity tests for the modern Kiva-compatible GraphQL surface."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias KivaWeb.KivaGraphql.Schema

  defp run(doc, ctx \\ %{locale: "en"}), do: Absinthe.run(doc, Schema, context: ctx)

  test "lend.loans returns a collection with Kiva field names + Money strings" do
    loan_fixture()

    doc = """
    { lend { loans(filters:{status:fundraising}, limit:5){
        totalCount
        values {
          id name status loanAmount
          loanFundraisingInfo { fundedAmount }
          geocode { country { isoCode region } }
          sector { name } gender distributionModel
          ... on LoanPartner { partnerName }
        }
    } } }
    """

    {:ok, res} = run(doc)
    refute res[:errors]
    coll = res.data["lend"]["loans"]
    assert coll["totalCount"] == 1
    assert [loan | _] = coll["values"]

    assert loan["status"] == "fundraising"
    # Money scalar renders cents as a 2-decimal string.
    assert loan["loanAmount"] == "1000.00"
    assert loan["loanFundraisingInfo"]["fundedAmount"] == "400.00"
    assert loan["geocode"]["country"]["isoCode"] == "GT"
    assert loan["geocode"]["country"]["region"] == "Central America"
    assert loan["distributionModel"] == "fieldPartner"
    # Interface resolves to LoanPartner.
    assert loan["partnerName"] == "Loom Co"
  end

  test "lend.loan(id) returns terms with expected payments" do
    %{loan: loan} = loan_fixture()

    {:ok, res} =
      run(
        "{ lend { loan(id: #{loan.id}){ id name terms { currency expectedPayments { amount } } } } }"
      )

    refute res[:errors]
    l = res.data["lend"]["loan"]
    assert l["id"] == loan.id
    assert l["terms"]["currency"] == "USD"
    assert [%{"amount" => _} | _] = l["terms"]["expectedPayments"]
  end

  test "my is null without authentication" do
    {:ok, res} = run("{ my { id } }", %{locale: "en", current_user: nil})
    assert res.data["my"] == nil
  end

  test "my returns the authenticated user's account and loans" do
    {:ok, user} =
      Kiva.Accounts.register_user(%{
        email: "me@kredo.test",
        password: "password",
        role: "lender",
        display_name: "Mo Lee"
      })

    {:ok, res} =
      run(
        "{ my { userAccount { email firstName } lender { name loanCount } loans { totalCount } } }",
        %{locale: "en", current_user: user}
      )

    refute res[:errors]
    assert res.data["my"]["userAccount"]["email"] == "me@kredo.test"
    assert res.data["my"]["userAccount"]["firstName"] == "Mo"
    assert res.data["my"]["lender"]["loanCount"] == 0
  end

  test "shop mutation requires an authenticated lender" do
    {:ok, res} = run("mutation { shop { createBasket } }", %{locale: "en", current_user: nil})
    assert res[:errors]
  end

  test "shop checkout records a lending and advances loan funding" do
    %{loan: loan} = loan_fixture()

    {:ok, user} =
      Kiva.Accounts.register_user(%{
        email: "buyer@kredo.test",
        password: "password",
        role: "lender",
        display_name: "Bee Yer"
      })

    ctx = %{locale: "en", current_user: user}

    {:ok, _} =
      run(
        "mutation { shop { updateLoanReservation(loanReservation:{loanId: #{loan.id}, amountCents: 5000}){ loanId } } }",
        ctx
      )

    {:ok, res} = run("mutation { shop { checkout } }", ctx)
    refute res[:errors]
    assert is_integer(res.data["shop"]["checkout"])

    assert Kiva.Repo.get!(Kiva.Lending.Loan, loan.id).funded_amount_cents == 45_000
  end
end
