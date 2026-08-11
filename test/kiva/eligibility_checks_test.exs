defmodule Kiva.EligibilityChecksTest do
  # A command's eligibility list is just strings, and a name with no matching
  # clause used to be answered `:ok` — a gate that reads as enforced and is not.
  # This walks the registry so that can never ship again.
  use Kiva.DataCase, async: true

  alias Kiva.Commands
  alias Kiva.Commands.Eligibility

  @actor %Kiva.Accounts.User{id: 0, role: "staff", managed_partner_id: nil}
  @params %{"loan_id" => "0", "loan_draft_id" => "0", "amount_cents" => "2500"}

  test "every eligibility check a command names is implemented" do
    for {command, spec} <- Commands.list(), check <- spec.eligibility do
      result =
        try do
          Eligibility.check(check, @actor, @params)
        rescue
          _ -> :raised_but_matched_a_clause
        end

      refute match?({:error, {:unknown_eligibility_check, _}}, result),
             "#{command} declares eligibility check #{inspect(check)}, " <>
               "but Kiva.Commands.Eligibility has no clause for it, so the gate never runs."
    end
  end

  test "an unrecognised check is refused, not waved through" do
    assert {:error, {:unknown_eligibility_check, "typo_in_the_registry"}} =
             Eligibility.check("typo_in_the_registry", @actor, @params)
  end
end
