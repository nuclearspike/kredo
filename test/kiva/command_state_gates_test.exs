defmodule Kiva.CommandStateGatesTest do
  # Every command below used to run with no state precondition at all: a stale
  # id, a second click on a queue someone else already cleared, or a typo in a
  # status either mutated something or crashed. These assert the refusal.
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Accounts, Commands, Repo}

  defp user(role) do
    {:ok, u} =
      Accounts.register_user(%{
        email: "gate-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: role
      })

    u
  end

  defp staff, do: user("admin")

  describe "the target has to exist" do
    test "a stale loan id is refused rather than crashing the handler" do
      params = %{"loan_id" => "0", "body" => "hi", "source_locale_code" => "en"}

      for {command, role} <- [
            {"record_repayment", "staff"},
            {"record_disbursal", "staff"},
            {"post_borrower_update", "staff"},
            {"submit_encouragement_message", "lender"}
          ] do
        assert {:error, {:ineligible, _check, reason}} =
                 Commands.execute(command, user(role), params)

        assert reason in [:loan_not_found, :no_repayment_due],
               "#{command} reported #{inspect(reason)}"
      end
    end

    test "a stale team id is refused" do
      assert {:error, {:ineligible, "team_exists", :team_not_found}} =
               Commands.execute("post_team_message", staff(), %{
                 "team_id" => "0",
                 "body" => "hi",
                 "source_locale_code" => "en"
               })
    end
  end

  describe "values the domain accepts" do
    test "a partner status outside active/suspended is refused, not persisted" do
      %{partner: partner} = partner_user_fixture()

      assert {:error, {:ineligible, "org_status_valid", {:invalid_status, "banana"}}} =
               Commands.execute("set_partner_status", staff(), %{
                 "partner_id" => to_string(partner.id),
                 "status" => "banana"
               })

      assert Repo.get!(Kiva.Partners.Partner, partner.id).status == "active"
    end

    test "an unsupported locale is refused" do
      assert {:error, {:ineligible, "locale_supported", :unsupported_locale}} =
               Commands.execute("set_locale", staff(), %{"locale_code" => "xx"})
    end
  end

  describe "the target is in a state where the action means something" do
    test "a loan cannot be disbursed twice" do
      %{loan: loan, user: partner_user} = partner_user_fixture()

      assert {:ok, _} =
               Commands.execute("record_disbursal", partner_user, %{
                 "loan_id" => to_string(loan.id)
               })

      assert {:error, {:ineligible, "loan_awaiting_disbursal", :already_disbursed}} =
               Commands.execute("record_disbursal", partner_user, %{
                 "loan_id" => to_string(loan.id)
               })
    end

    test "a translation already decided cannot be approved again" do
      %{draft: draft} = submitted_loan_fixture()

      row =
        Repo.one!(
          from lc in Kiva.Lending.LoanLc,
            where: lc.loan_id == ^draft.id and lc.translation_status == "machine",
            limit: 1
        )

      approve = fn ->
        Commands.execute("approve_translation", staff(), %{
          "lc_entity_type" => "loan",
          "lc_id" => to_string(row.id)
        })
      end

      assert {:ok, _} = approve.()

      assert {:error, {:ineligible, "translation_awaiting_review", :translation_already_reviewed}} =
               approve.()
    end

    test "revoking a permission the user only inherits reports that it is not theirs" do
      lender = staff()

      assert {:error, {:ineligible, "direct_grant_exists", :no_direct_grant}} =
               Commands.execute("revoke_permission", staff(), %{
                 "user_id" => to_string(lender.id),
                 "permission_key" => "approve_loan_listing"
               })
    end
  end

  describe "the actor stands in the right relationship to the target" do
    test "a partner account not linked to an organization cannot open an application" do
      assert {:error, {:ineligible, "actor_manages_partner", :not_a_partner}} =
               Commands.execute("start_loan_application", user("partner"), %{})
    end

    test "a partner cannot start an application for another partner's borrower" do
      %{user: partner_user} = partner_user_fixture()
      %{borrower: other_borrower} = partner_user_fixture()

      assert {:error, {:ineligible, "partner_owns_borrower", :not_owner}} =
               Commands.execute("start_loan_application", partner_user, %{
                 "borrower_id" => to_string(other_borrower.id)
               })
    end
  end
end
