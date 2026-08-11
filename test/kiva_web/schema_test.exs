defmodule KivaWeb.SchemaTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures

  defp run(doc, ctx), do: Absinthe.run(doc, KivaWeb.Schema, context: ctx)

  test "public localizedLoans returns localized cards" do
    loan_fixture()

    {:ok, res} =
      run("{ localizedLoans { title fundedPercent countryCode } }", %{
        actor_role: "public",
        locale: "en"
      })

    assert [%{"title" => "Weaving loan", "fundedPercent" => 40} | _] = res.data["localizedLoans"]
  end

  test "localizedLoan resolves es content" do
    %{loan: loan} = loan_fixture()

    {:ok, res} =
      run("{ localizedLoan(slug: \"#{loan.slug}\", locale: \"es\"){ title borrowerStory } }", %{
        actor_role: "public"
      })

    assert res.data["localizedLoan"]["title"] == "Préstamo de tejido"
    assert res.data["localizedLoan"]["borrowerStory"] =~ "Rosa teje"
  end

  test "staff_review_queue_count is denied to public and allowed to staff" do
    {:ok, denied} = run("{ staffReviewQueueCount }", %{actor_role: "public"})
    assert denied[:errors]

    {:ok, ok} = run("{ staffReviewQueueCount }", %{actor_role: "staff"})
    assert ok.data["staffReviewQueueCount"] == 0
  end

  test "audit_events is admin-only" do
    {:ok, denied} = run("{ auditEvents { eventType } }", %{actor_role: "lender"})
    assert denied[:errors]

    {:ok, ok} = run("{ auditEvents { eventType } }", %{actor_role: "admin"})
    refute ok[:errors]
  end

  test "borrowerImage is exposed while fundraising and hidden afterwards" do
    %{loan: fundraising, borrower: bf} = loan_fixture(%{slug: "gql-fr"})
    Kiva.Repo.update!(Ecto.Changeset.change(bf, image_url: "/img/fund.jpg"))

    %{loan: done, borrower: bc} =
      loan_fixture(%{slug: "gql-done", status: "completed", funded_amount_cents: 100_000})

    Kiva.Repo.update!(Ecto.Changeset.change(bc, image_url: "/img/done.jpg"))

    {:ok, res} =
      run(
        "{ a: localizedLoan(slug: \"#{fundraising.slug}\"){ status borrowerImage }" <>
          " b: localizedLoan(slug: \"#{done.slug}\"){ status borrowerImage } }",
        %{actor_role: "public", locale: "en"}
      )

    assert res.data["a"] == %{"status" => "fundraising", "borrowerImage" => "/img/fund.jpg"}
    assert res.data["b"] == %{"status" => "completed", "borrowerImage" => nil}
  end

  test "me requires authentication" do
    {:ok, denied} = run("{ me { email } }", %{actor_role: "public"})
    assert denied[:errors]
    assert denied.data["me"] == nil
  end

  test "me returns the user's own loans, teams, and portfolio" do
    %{loan: loan} = loan_fixture()

    {:ok, lender} =
      Kiva.Accounts.register_user(%{
        email: "me-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    Kiva.Portfolio.lend(lender, loan.id, 2500)

    {:ok, res} =
      run("{ me { email lendings { loanSlug amountCents } portfolio { count totalCents } } }", %{
        current_user: lender,
        actor_role: "lender",
        locale: "en"
      })

    me = res.data["me"]
    assert me["email"] == lender.email
    assert me["lendings"] == [%{"loanSlug" => loan.slug, "amountCents" => 2500}]
    assert me["portfolio"] == %{"count" => 1, "totalCents" => 2500}
  end
end
