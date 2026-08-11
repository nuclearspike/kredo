defmodule Kiva.AdminReviewTest do
  @moduledoc "A3/A6 — loan review detail + reconstructable audit + AI tool-call inspection."
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Lending, Audit, AI}

  test "review_queue items carry a detail with translation coverage and a missing-fields list" do
    submitted_loan_fixture()
    [item | _] = Lending.review_queue("en")

    assert is_map(item.detail)
    assert is_list(item.detail.translations)
    assert is_list(item.detail.missing)
    assert Enum.any?(item.detail.translations, &(&1.locale == "en"))
  end

  test "list_events filters by event-type prefix (audit reconstruction)" do
    Audit.record(%{event_type: "permission.revoked", summary: "x"})
    Audit.record(%{event_type: "loan.approved", summary: "y"})

    types = Audit.list_events(event_type: "permission") |> Enum.map(& &1.event_type)
    assert "permission.revoked" in types
    refute "loan.approved" in types

    # backward-compatible integer arity still works
    assert is_list(Audit.list_events(5))
  end

  test "recent_tool_calls and list_tool_calls round-trip for the AI inspector" do
    conv = AI.start_conversation(%{actor_role: "lender", locale_code: "en"})

    AI.record_tool_call(conv.id, %{
      tool_type: "graphql",
      schema_surface: "LenderGraphQL",
      operation_name: "lend",
      allowed: true
    })

    assert [_ | _] = AI.recent_tool_calls(25)
    assert [tc] = AI.list_tool_calls(conv.id)
    assert tc.operation_name == "lend"
  end
end
