defmodule Kiva.AI.AssistantTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.AI
  alias Kiva.AI.Assistant

  defp ctx do
    conv = AI.start_conversation(%{actor_role: "public", locale: "en"})
    %{conversation_id: conv.id, actor: nil, role: "public", locale: "en", page: "loans"}
  end

  test "Ask Mode: 'show me loans' runs scoped GraphQL and records a tool call" do
    loan_fixture()
    c = ctx()
    res = Assistant.respond(c, "show me loans")
    assert res.mode == "ask"
    assert res.reply =~ "Weaving loan" or res.reply =~ "support"
    assert Enum.any?(AI.list_tool_calls(c.conversation_id), &(&1.tool_type == "graphql_query"))
  end

  test "Command Mode: 'switch to spanish' proposes a set_locale preview" do
    c = ctx()
    res = Assistant.respond(c, "switch to spanish")
    assert res.mode == "command"
    assert res.action.command_key == "set_locale"
    assert res.action.params["locale_code"] == "es"
    # the preview was persisted
    assert AI.get_action_preview!(res.action.preview_id).command_key == "set_locale"
  end

  test "help lists capabilities" do
    res = Assistant.respond(ctx(), "what can you do?")
    assert res.mode == "ask"
    assert res.reply =~ "assistant"
  end

  defp lender_ctx do
    {:ok, lender} =
      Kiva.Accounts.register_user(%{
        email: "al-#{System.unique_integer([:positive])}@kredo.test",
        password: "password",
        role: "lender"
      })

    conv = AI.start_conversation(%{actor_role: "lender", locale: "en"})

    {%{conversation_id: conv.id, actor: lender, role: "lender", locale: "en", page: "loans"},
     lender}
  end

  test "Command Mode: a lender can lend via chat (preview + confirm action)" do
    loan_fixture()
    {c, _lender} = lender_ctx()
    res = Assistant.respond(c, "lend $50 to weaving")
    assert res.mode == "command"
    assert res.action.command_key == "complete_demo_lend"
    assert res.action.params["amount_cents"] == "5000"
  end

  test "Ask Mode: portfolio summary for a lender" do
    loan = loan_fixture().loan
    {c, lender} = lender_ctx()
    Kiva.Portfolio.lend(lender, loan.id, 2500)
    res = Assistant.respond(c, "what's my impact?")
    assert res.mode == "ask"
    assert res.reply =~ "supported 1 loans"
  end

  test "a non-lender asking to lend is declined gracefully" do
    loan_fixture()
    res = Assistant.respond(ctx(), "lend $25 to weaving")
    assert res.mode == "command"
    assert is_nil(res.action)
  end
end
