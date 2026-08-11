defmodule Kiva.AI.SetupHintTest do
  # Everyone runs this on their own laptop, so the assistant has to say how to
  # connect a model rather than silently degrading to its script.
  use Kiva.DataCase, async: false

  alias Kiva.AI
  alias Kiva.AI.{Assistant, LLM}

  setup do
    prior = Application.get_env(:kiva, :ai_llm_enabled)
    on_exit(fn -> Application.put_env(:kiva, :ai_llm_enabled, prior) end)
    :ok
  end

  defp ask(text) do
    conv = AI.start_conversation(%{actor_role: "public", locale: "en", page_context: %{}})

    Assistant.respond(
      %{conversation_id: conv.id, actor: nil, role: "public", locale: "en", page: "loans"},
      text
    )
  end

  test "with no model connected, an unscripted question explains the setup" do
    Application.put_env(:kiva, :ai_llm_enabled, true)
    assert LLM.needs_setup?()

    reply = ask("tell me a joke about elephants").reply

    assert reply =~ "OPENAI_API_KEY"
    assert reply =~ "KIVA_LLM_ENDPOINT"
  end

  test "a deliberately disabled model is not treated as a setup gap" do
    Application.put_env(:kiva, :ai_llm_enabled, false)
    refute LLM.needs_setup?()
    refute LLM.configured?()

    refute ask("tell me a joke about elephants").reply =~ "OPENAI_API_KEY"
  end

  test "scripted questions still work offline" do
    Application.put_env(:kiva, :ai_llm_enabled, true)
    refute ask("how does repayment work?").reply =~ "OPENAI_API_KEY"
  end
end
