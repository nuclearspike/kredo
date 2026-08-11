defmodule KivaWeb.DeveloperDocsTest do
  @moduledoc "CodeGen + the AI query-builder fallback (no DB / no network)."
  use ExUnit.Case, async: true

  alias KivaWeb.Developer.{Docs, CodeGen}

  test "CodeGen renders every language for every endpoint, hitting the right path" do
    for ep <- Docs.endpoints(), lang <- CodeGen.languages() do
      code = CodeGen.render(ep, lang)
      assert is_binary(code) and code != ""
      assert String.contains?(code, ep.path)
    end
  end

  test "api-key endpoints render the bearer header" do
    ep = Enum.find(Docs.endpoints(), &(&1.id == "v2_me"))
    assert CodeGen.render(ep, :curl) =~ "kva_live_"
  end

  test "agents_markdown covers all three surfaces" do
    md = Docs.agents_markdown()
    assert md =~ "Platform REST (v2)"
    assert md =~ "Kiva Modern GraphQL"
    assert md =~ "Kiva Legacy REST"
    assert md =~ "/api/v2/me"
  end

  test "DocsAssistant falls back deterministically when the LLM is disabled" do
    # config/test.exs sets ai_llm_enabled: false
    res =
      Kiva.AI.DocsAssistant.generate(%{
        intent: "list fundraising loans",
        language: "python",
        surface: "platform_rest",
        locale: "en"
      })

    assert res.source == :fallback
    assert res.snippet =~ "requests"
    assert is_binary(res.summary)
  end
end
