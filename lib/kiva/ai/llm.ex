defmodule Kiva.AI.LLM do
  @moduledoc """
  Real-LLM backend for the page-aware assistant. Talks to any OpenAI-compatible
  chat-completions endpoint — a hosted provider, or a model running on the same
  machine — with a role + page + locale aware system prompt assembled from the
  contracts in `prompts/chatbot_system_prompt_templates.md`.

  Returns `nil` on any failure (disabled, no key, provider/parse error) so
  `Kiva.AI.Assistant` transparently degrades to its deterministic mock. The
  deterministic command path (set_locale / lend preview+confirm) stays in the
  Assistant — the LLM only handles conversational "ask" turns.
  """
  require Logger
  alias Kiva.AI

  # With nothing configured, try a model on this machine: LM Studio, Ollama's
  # OpenAI-compatible port, or anything else speaking the same protocol. Override
  # the address with KIVA_LLM_ENDPOINT and the model id with OPENAI_MODEL.
  @local_endpoint "http://127.0.0.1:1234/v1/chat/completions"
  @default_model "gpt-4o-mini"

  # --- System prompt contracts (source: prompts/chatbot_system_prompt_templates.md) ---
  @global """
  You are the Kredo demo assistant. You are page-aware and role-aware. You may answer questions, explain data, help people navigate, draft content, collect missing information, and propose actions.

  You must not mutate state directly. Consequential actions go through registered commands and require explicit confirmation. Use only the data the current role is allowed to see — never expose hidden admin/private data, staff risk notes, or another user's private information. Never claim repayment is guaranteed. Never present weak inference as fact; if data is missing, say what is missing and what can be done next.
  """

  @role_additions %{
    "lender" =>
      "Role: LENDER. Help them discover loans, understand risk honestly, build a portfolio, join or create teams, and write encouragement messages. Encourage generosity without coercion. Borrower-visible messages must pass moderation before sending.",
    "borrower" =>
      "Role: BORROWER. Help them understand their own loans, repayments, funding progress, lender messages, and next steps, in supportive plain language. Never expose staff risk notes, lender private info, or internal moderation details.",
    "partner" =>
      "Role: PARTNER (field partner / MFI). Help them create and manage borrower and loan applications with chat-first guided collection. Reuse prior borrower details only after showing your confidence and asking for confirmation. Always steer toward a structured review before submission.",
    "staff" =>
      "Role: STAFF. Help inspect review queues, translations, moderation, permissions, risk, and audit logs. High-risk actions require preview and confirmation.",
    "admin" =>
      "Role: ADMIN. Help inspect and operate review queues, translations, moderation, permissions, analytics, and audit logs. High-risk administrative actions require preview and confirmation.",
    "public" =>
      "Role: VISITOR (not signed in). Help them understand how Kredo lending works and explore loans. To lend, they need to sign in as a lender."
  }

  @moderation "When a borrower-visible message is unkind, patronizing, romantic, politically/religiously pressuring, solicitational, or privacy-invasive, do not encourage sending it — explain the issue and offer a kinder rewrite."

  @pages %{
    "loans" => "the loan browse page, where lenders find borrowers to support",
    "loan_profile" => "a loan detail page",
    "partner" =>
      "the partner workspace, where partners create and manage borrower loan applications",
    "partner_profile" => "a field partner's public profile",
    "portfolio" => "the lender's 'My impact' portfolio page",
    "basket" => "the lender's lending basket",
    "faq" => "the Help & FAQ page",
    "teams" => "the lending teams page",
    "team_profile" => "a lending team page",
    "portal" => "the borrower's portal",
    "admin" => "the staff/admin operations dashboard"
  }

  @locale_names %{
    "en" => "English",
    "es" => "Spanish",
    "de" => "German",
    "fr" => "French",
    "nl" => "Dutch"
  }

  # Talking to OpenAI directly is the path for someone running this on a laptop
  # with nothing else installed; KIVA_LLM_ENDPOINT points at anything else that
  # speaks the same protocol (LM Studio, Ollama, a gateway).
  @openai_endpoint "https://api.openai.com/v1/chat/completions"

  @doc """
  True when someone has actually pointed this app at a model.

  The endpoint and token both have defaults, so their presence proves nothing;
  what proves it is an explicit environment variable. Without one, the assistant
  answers from its offline script and offers setup instructions rather than
  timing out against an endpoint that was never running.
  """
  def configured?,
    do: not disabled_by_config?() and not is_nil(configured_source())

  @doc "True when the app should explain how to connect a model."
  def needs_setup?, do: not disabled_by_config?() and is_nil(configured_source())

  # Tests and demos switch the model off deliberately; that is not a setup gap.
  defp disabled_by_config?,
    do: Application.get_env(:kiva, :ai_llm_enabled, true) == false

  defp configured_source do
    Enum.find(
      ~w(OPENAI_API_KEY KIVA_LLM_ENDPOINT LLM_API_TOKEN LLM_API_TOKEN_FILE),
      &(System.get_env(&1) not in [nil, ""])
    )
  end

  @doc "True when the LLM backend is enabled and pointed at a model."
  def enabled?, do: configured?()

  @doc "Answer one conversational turn via the LLM. Returns the reply string, or nil to fall back to the mock."
  def answer(ctx) do
    if enabled?(), do: do_answer(ctx), else: nil
  end

  defp do_answer(ctx) do
    case chat_completion([%{role: "system", content: system_prompt(ctx)} | history(ctx)], 2000) do
      {:ok, content} ->
        record_call(ctx, true, nil)
        String.trim(content)

      {:error, reason} ->
        record_call(ctx, false, "provider error: #{reason}")
        nil
    end
  end

  defp history(ctx) do
    AI.get_conversation!(ctx.conversation_id).messages
    |> Enum.filter(
      &(&1.role in ["user", "assistant"] and is_binary(&1.content) and &1.content != "")
    )
    |> Enum.take(-10)
    |> Enum.map(&%{role: &1.role, content: &1.content})
  end

  defp system_prompt(ctx) do
    [
      @global,
      Map.get(@role_additions, ctx.role, @role_additions["public"]),
      @moderation,
      "Context: the user is on #{Map.get(@pages, ctx.page, "the #{ctx.page} page")}.",
      "Always reply in #{Map.get(@locale_names, ctx.locale, "English")} unless the user explicitly asks for another language.",
      "This is a DEMO with simulated data — no real money moves and repayments are simulated; never imply otherwise.",
      "Keep replies warm and concise: a few short sentences or a short list. Offer a concrete next step when useful."
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map_join("\n\n", &String.trim/1)
  end

  defp record_call(ctx, ok?, reason) do
    AI.record_tool_call(ctx.conversation_id, %{
      tool_type: "llm",
      schema_surface: "llm",
      operation_name: "chat.completions",
      allowed: ok?,
      denial_reason: reason,
      request: %{"model" => model()},
      response_summary: (ok? && "ok") || "error"
    })
  rescue
    _ -> :ok
  end

  # --- Developer-docs query builder ---------------------------------------
  @docs_system """
  You are the Kredo API assistant embedded in the developer documentation.
  Turn a developer's natural-language request into ONE concrete, runnable API call
  in the requested programming language. Never invent endpoints or fields. ALWAYS
  honor the API surface and output language the user specifies — never substitute a
  different surface or language, even if another seems more natural. Use ONLY these
  surfaces (base URL http://localhost:4000):

  PLATFORM REST (/api/v2, JSON; auth = API key via `Authorization: Bearer kva_live_...` or `X-API-Key`):
    GET /api/v2/loans?locale=&status=&country_code=&q=         (public)
    GET /api/v2/loans/{slug}?locale=                            (public)
    GET /api/v2/partners/{slug}?locale= ; GET /api/v2/teams ; GET /api/v2/teams/{slug} ; GET /api/v2/faq  (public)
    POST /api/v2/auth/login {email,password} -> {token}         (public)
    GET /api/v2/me ; /api/v2/me/loans ; /api/v2/me/teams ; /api/v2/me/portfolio   (API key)

  PLATFORM GRAPHQL (POST /api/graphql, body {query,variables}; auth = API key):
    queries: viewer; localizedLoans(locale,sector_id,country_code,trust_model,q); localizedLoan(slug,locale);
    localizedPartner(slug,locale); faqEntries(locale); me { email role lendings{loanSlug amountCents} teams{name} portfolio{count totalCents} }

  KIVA MODERN GRAPHQL (POST /graphql; OAuth2 bearer for my/shop):
    { lend { loan(id) loans(filters,sortBy,limit,offset){ totalCount values { id name loanAmount ... on LoanPartner{partnerName} ... on LoanDirect{businessName} } } sector activity } }
    { my { userAccount lender loans(limit,offset){totalCount values{id name}} teams } }   (auth)

  KIVA LEGACY REST (/v1, .json; OAuth2 bearer for my/*):
    GET /v1/loans/search.json?status=&gender=&country_code=&sector=&q=&page=&per_page=
    GET /v1/loans/{ids}.json ; /v1/loans/{id}/lenders.json ; /v1/partners.json ; /v1/teams/search.json
    GET /v1/my/{lender,loans,teams}.json   (OAuth2 bearer)
    POST /oauth/token {grant_type,username,password} -> {access_token}

  Locales: add locale=en|es|de|fr|nl (REST query string or GraphQL argument).

  Respond with ONLY a JSON object (no markdown fence, no prose around it):
  {"summary":"<one line: what this call does>","language":"<the requested language>","snippet":"<a complete runnable snippet in that language>","notes":"<one short tip about auth or locale>"}
  """

  @doc """
  Build an example API call from a natural-language request. `req` is
  `%{intent, language, surface, locale}`. Returns `{:ok, %{summary, language,
  snippet, notes}}` or `{:error, reason}` (so the caller can fall back).
  """
  def docs_query(%{intent: intent} = req) when is_binary(intent) do
    if enabled?(), do: do_docs_query(req), else: {:error, :disabled}
  end

  defp do_docs_query(req) do
    user = %{role: "user", content: docs_user_prompt(req)}

    case chat_completion([%{role: "system", content: @docs_system}, user], 2000) do
      {:ok, content} -> parse_docs(content, req)
      {:error, reason} -> {:error, reason}
    end
  end

  defp docs_user_prompt(req) do
    lang = req[:language] || "curl"

    surface_rule =
      case req[:surface] do
        s when s in [nil, "", "any"] ->
          "API surface: choose the single most appropriate one."

        s ->
          "API surface (REQUIRED): use ONLY the #{surface_label(s)} and no other surface."
      end

    """
    #{surface_rule}
    Output language (REQUIRED): write the snippet in #{lang}.
    User request: #{String.slice(req.intent, 0, 500)}
    """
  end

  defp surface_label("platform_rest"), do: "Platform REST API (base /api/v2)"
  defp surface_label("platform_graphql"), do: "Platform GraphQL API (POST /api/graphql)"
  defp surface_label("kiva_graphql"), do: "Kiva Modern GraphQL API (POST /graphql)"
  defp surface_label("kiva_rest"), do: "Kiva Legacy REST API (base /v1, .json suffix)"
  defp surface_label(other), do: to_string(other)

  defp parse_docs(content, req) do
    json =
      content
      |> String.trim()
      |> String.replace(~r/^```[a-zA-Z]*\n/, "")
      |> String.replace(~r/\n```$/, "")

    case Jason.decode(json) do
      {:ok, %{"snippet" => snippet} = m} when is_binary(snippet) ->
        {:ok,
         %{
           summary: m["summary"] || "",
           language: m["language"] || req[:language],
           snippet: snippet,
           notes: m["notes"] || ""
         }}

      _ ->
        {:error, :parse}
    end
  end

  # --- transport ----------------------------------------------------------
  defp chat_completion(messages, max_tokens) do
    body = %{model: model(), messages: messages, max_tokens: max_tokens, stream: false}

    case Req.post(endpoint(),
           headers: auth_headers(),
           json: body,
           receive_timeout: 45_000,
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}}
      when is_binary(content) and content != "" ->
        {:ok, content}

      {:ok, %{status: status, body: b}} ->
        Logger.warning("AI.LLM #{status}: #{inspect(b) |> String.slice(0, 200)}")
        {:error, :provider}

      other ->
        Logger.warning("AI.LLM transport error: #{inspect(other) |> String.slice(0, 200)}")
        {:error, :provider}
    end
  rescue
    e ->
      Logger.warning("AI.LLM exception: #{inspect(e) |> String.slice(0, 200)}")
      {:error, :exception}
  end

  # A model running locally usually needs no credential at all; only send the
  # header when there is something to send.
  defp auth_headers do
    case api_token() do
      nil -> []
      token -> [{"authorization", "Bearer #{token}"}]
    end
  end

  defp endpoint do
    cond do
      e = System.get_env("KIVA_LLM_ENDPOINT") -> e
      System.get_env("OPENAI_API_KEY") -> @openai_endpoint
      true -> @local_endpoint
    end
  end

  defp model, do: System.get_env("OPENAI_MODEL") || @default_model

  # Credential for the endpoint, if it wants one. OPENAI_API_KEY for a hosted
  # provider, LLM_API_TOKEN for anything else, or LLM_API_TOKEN_FILE pointing at a
  # file holding the raw token or an `API_TOKEN=...` line. Nil means send none,
  # which is what a model on this machine usually expects.
  defp api_token,
    do: System.get_env("OPENAI_API_KEY") || System.get_env("LLM_API_TOKEN") || file_token()

  defp file_token do
    with path when is_binary(path) <- System.get_env("LLM_API_TOKEN_FILE"),
         {:ok, content} <- File.read(Path.expand(path)) do
      case Regex.run(~r/^API_TOKEN=(.+)$/m, content) do
        [_, tok] ->
          tok |> String.trim() |> String.trim("\"") |> String.trim("'")

        nil ->
          case String.trim(content),
            do: (
              "" -> nil
              tok -> tok
            )
      end
    else
      _ -> nil
    end
  end
end
