defmodule Kiva.AI.Assistant do
  @moduledoc """
  The page-aware chat engine. A deterministic, rule-based **mock LLM** (no
  external provider in v1 — keeps the demo offline and key-free), structured so a
  real provider can drop in behind the same boundary:

    * Ask Mode  — answers questions by running **role-scoped GraphQL** against
      `KivaWeb.Schema`; it never reads outside the actor's surface.
    * Command Mode — maps an intent to a registered command, builds a safe
      **preview**, and proposes a confirm action. It never mutates directly;
      execution goes through `Kiva.Commands` after the actor confirms.

  Every turn (user message, assistant reply, tool call, action preview) is
  persisted via `Kiva.AI` for admin reconstruction.
  """
  alias Kiva.{AI, Commands}

  @langs %{
    "spanish" => "es",
    "español" => "es",
    "espanol" => "es",
    "german" => "de",
    "deutsch" => "de",
    "french" => "fr",
    "français" => "fr",
    "francais" => "fr",
    "dutch" => "nl",
    "nederlands" => "nl",
    "english" => "en"
  }

  @doc """
  Handle one user turn. `ctx` = %{conversation_id, actor, role, locale, page}.
  Returns %{reply: String, mode: "ask"|"command", action: nil | map}.
  """
  def respond(ctx, text) do
    AI.add_message(ctx.conversation_id, "user", text, "user")
    norm = String.downcase(text)

    result =
      cond do
        code = language_command(norm) -> command_set_locale(ctx, code)
        lend = lend_command(norm) -> command_lend(ctx, lend)
        true -> answer(ctx, norm)
      end

    AI.add_message(ctx.conversation_id, "assistant", result.reply, result.mode, %{
      action: result[:action]
    })

    result
  end

  # Conversational turns go to Kiva.AI.LLM when a model is connected; nil back from
  # it (switched off, unconfigured, or a failed call) falls through to the scripted
  # answers below. Commands (set_locale/lend) are matched above this and never reach
  # the model, so the preview+confirm path does not depend on one being available.
  defp answer(ctx, norm) do
    case Kiva.AI.LLM.answer(ctx) do
      reply when is_binary(reply) and reply != "" ->
        %{reply: reply, mode: "ask", action: nil}

      _ ->
        cond do
          portfolio_intent?(norm) -> ask_portfolio(ctx)
          loans_intent?(norm) -> ask_loans(ctx, norm)
          faq_intent?(norm) -> ask_faq(ctx, norm)
          help_intent?(norm) -> help(ctx)
          true -> fallback(ctx)
        end
    end
  end

  # --- intent detection ---
  defp language_command(norm) do
    intent? =
      Regex.match?(~r/\b(language|switch|change|speak|translate|set)\b/, norm) or
        String.contains?(norm, " in ")

    if intent? do
      Enum.find_value(@langs, fn {word, code} -> String.contains?(norm, word) && code end)
    end
  end

  defp loans_intent?(n),
    do:
      String.contains?(n, "loan") or String.contains?(n, "borrow") or String.contains?(n, "fund") or
        String.contains?(n, "support")

  defp faq_intent?(n),
    do:
      String.contains?(n, "how") or String.contains?(n, "repay") or String.contains?(n, "what is") or
        String.contains?(n, "explain")

  defp help_intent?(n),
    do:
      String.contains?(n, "help") or String.contains?(n, "what can you") or
        String.contains?(n, "do you do")

  # --- Command Mode ---
  defp command_set_locale(ctx, code) do
    case Commands.preview("set_locale", ctx.actor, %{"locale_code" => code}) do
      {:ok, preview} ->
        ap =
          AI.create_action_preview(ctx.conversation_id, %{
            command_key: "set_locale",
            target_type: "session",
            preview: stringify(preview),
            risk_level: preview.risk
          })

        AI.record_tool_call(ctx.conversation_id, %{
          tool_type: "command_preview",
          operation_name: "set_locale",
          allowed: true,
          request: %{"locale_code" => code},
          response_summary: preview.summary
        })

        %{
          reply: "I can switch the site language to #{lang_name(code)}. #{preview.summary}",
          mode: "command",
          action: %{
            type: "confirm_command",
            preview_id: ap.id,
            command_key: "set_locale",
            params: %{"locale_code" => code},
            label: "Switch to #{lang_name(code)}"
          }
        }

      {:error, reason} ->
        AI.record_tool_call(ctx.conversation_id, %{
          tool_type: "command_preview",
          operation_name: "set_locale",
          allowed: false,
          denial_reason: inspect(reason)
        })

        %{reply: "I can't do that: #{inspect(reason)}.", mode: "command", action: nil}
    end
  end

  # --- Ask Mode (scoped GraphQL) ---
  defp ask_loans(ctx, norm) do
    doc = "query($loc:String){ localizedLoans(locale:$loc){ title fundedPercent countryCode } }"
    {data, _} = run_graphql(ctx, doc, %{"loc" => ctx.locale}, "localizedLoans")
    loans = get_in(data, ["localizedLoans"]) || []

    almost? =
      String.contains?(norm, "almost") or String.contains?(norm, "nearly") or
        String.contains?(norm, "close")

    loans = if almost?, do: Enum.sort_by(loans, & &1["fundedPercent"], :desc), else: loans

    header =
      if almost?,
        do: "Almost-funded loans you can help finish:",
        else: "There are #{length(loans)} loans you can support:"

    reply =
      case loans do
        [] ->
          "There are no loans matching right now. Try browsing all loans."

        list ->
          lines =
            list
            |> Enum.take(4)
            |> Enum.map(fn l ->
              "• #{l["title"]} (#{l["countryCode"]}) — #{l["fundedPercent"]}% funded"
            end)
            |> Enum.join("\n")

          "#{header}\n#{lines}\n\nOpen the Loans page to fund one."
      end

    %{reply: reply, mode: "ask", action: nil}
  end

  defp ask_faq(ctx, norm) do
    doc = "query($loc:String){ faqEntries(locale:$loc){ question answer } }"
    {data, _} = run_graphql(ctx, doc, %{"loc" => ctx.locale}, "faqEntries")
    entries = get_in(data, ["faqEntries"]) || []

    match =
      Enum.find(entries, fn e ->
        q = String.downcase(e["question"] || "")

        (String.contains?(norm, "repay") and String.contains?(q, "repay")) or
          (String.contains?(norm, "work") and String.contains?(q, "work")) or
          (String.contains?(norm, "partner") and String.contains?(q, "partner"))
      end)

    reply =
      cond do
        match ->
          match["answer"]

        entries != [] ->
          "I can explain: " <> Enum.map_join(entries, "; ", & &1["question"]) <> ". Which one?"

        true ->
          "Visit the Help & FAQ page to learn how lending works."
      end

    %{reply: reply, mode: "ask", action: nil}
  end

  defp help(ctx) do
    cmds = Commands.for_actor(ctx.role) |> Map.keys() |> Enum.sort()

    actions =
      if cmds == [],
        do: "",
        else: "\n\nAs a #{ctx.role}, you can ask me to: #{Enum.join(cmds, ", ")}."

    %{
      reply:
        "I'm your page-aware assistant. I can explain how lending works, find loans, and switch your language — in your language. Try “show me loans” or “switch to Spanish”." <>
          actions,
      mode: "ask",
      action: nil
    }
  end

  # The offline script handles the demo's set pieces. Anything outside it needs a
  # real model, and on a laptop that means the reader has to connect one, so say
  # how instead of repeating the menu they just fell off the end of.
  defp fallback(ctx) do
    reply =
      if Kiva.AI.LLM.needs_setup?() do
        setup_instructions()
      else
        "I can help you browse loans, explain repayment and trust models, and switch languages. Try “show me loans”, “how does repayment work?”, or “switch to German”."
      end

    %{reply: reply, mode: "ask", action: nil}
    |> tap(fn _ -> ctx end)
  end

  @doc """
  What to tell someone whose copy has no model connected. Deliberately concrete:
  the exact variable, one command, and what changes once it is set.
  """
  def setup_instructions do
    """
    I'm running without a language model, so I can only handle the scripted demo questions — try “show me loans”, “how does repayment work?”, or “switch to Spanish”.

    To switch on the full assistant, give the app an API key and restart it:

      export OPENAI_API_KEY=sk-...
      mix phx.server

    Prefer to keep it on your machine? Point it at anything that speaks the OpenAI chat API — LM Studio, Ollama, a gateway — and no key is needed:

      export KIVA_LLM_ENDPOINT=http://127.0.0.1:1234/v1/chat/completions
      export OPENAI_MODEL=your-local-model

    Nothing else in the demo needs either one.
    """
  end

  # --- GraphQL runner: executes through the role-scoped schema + records it ---
  defp run_graphql(ctx, doc, vars, op) do
    context = %{actor_role: ctx.role, locale: ctx.locale, current_user: ctx.actor}

    case Absinthe.run(doc, KivaWeb.Schema, variables: vars, context: context) do
      {:ok, %{data: data}} ->
        AI.record_tool_call(ctx.conversation_id, %{
          tool_type: "graphql_query",
          schema_surface: surface_for(ctx.role),
          operation_name: op,
          allowed: true,
          request: vars,
          response_summary: "ok"
        })

        {data, nil}

      {:ok, %{errors: errors}} ->
        AI.record_tool_call(ctx.conversation_id, %{
          tool_type: "graphql_query",
          operation_name: op,
          allowed: false,
          denial_reason: inspect(errors)
        })

        {%{}, errors}

      other ->
        {%{}, other}
    end
  end

  defp surface_for(role) when role in ["staff", "admin"], do: "StaffGraphQL"
  defp surface_for("lender"), do: "LenderGraphQL"
  defp surface_for("borrower"), do: "BorrowerGraphQL"
  defp surface_for("partner"), do: "PartnerGraphQL"
  defp surface_for(_), do: "PublicGraphQL"

  # --- Lender intents (Item 8) ---
  defp portfolio_intent?(n),
    do:
      String.contains?(n, "impact") or String.contains?(n, "portfolio") or
        String.contains?(n, "my lending") or String.contains?(n, "repaid")

  defp lend_command(norm) do
    if String.match?(norm, ~r/\blend\b/) and
         (String.contains?(norm, " to ") or String.match?(norm, ~r/\$?\d/)) do
      amount =
        case Regex.run(~r/\$?(\d+)/, norm) do
          [_, n] -> String.to_integer(n) * 100
          _ -> 2500
        end

      query =
        case String.split(norm, " to ", parts: 2) do
          [_, rest] -> String.trim(rest)
          _ -> nil
        end

      %{amount_cents: amount, query: query}
    end
  end

  defp command_lend(ctx, %{amount_cents: amount, query: query}) do
    case find_loan(ctx.locale, query) do
      nil ->
        %{
          reply: "I couldn't find a loan matching that. Try the borrower or loan name.",
          mode: "command",
          action: nil
        }

      match ->
        case Commands.preview("complete_demo_lend", ctx.actor, %{
               "loan_id" => match.loan.id,
               "amount_cents" => amount
             }) do
          {:ok, preview} ->
            money = Kiva.Localization.format_money(amount, "USD", ctx.locale)

            ap =
              AI.create_action_preview(ctx.conversation_id, %{
                command_key: "complete_demo_lend",
                target_type: "loan",
                target_id: to_string(match.loan.id),
                preview: stringify(preview),
                risk_level: preview.risk
              })

            AI.record_tool_call(ctx.conversation_id, %{
              tool_type: "command_preview",
              operation_name: "complete_demo_lend",
              allowed: true,
              request: %{"loan_id" => match.loan.id, "amount_cents" => amount},
              response_summary: "preview"
            })

            %{
              reply: "I can lend #{money} to #{match.title}. Confirm to lend.",
              mode: "command",
              action: %{
                type: "confirm_command",
                preview_id: ap.id,
                command_key: "complete_demo_lend",
                params: %{
                  "loan_id" => to_string(match.loan.id),
                  "amount_cents" => to_string(amount)
                },
                label: "Lend #{money} to #{match.title}"
              }
            }

          {:error, reason} ->
            AI.record_tool_call(ctx.conversation_id, %{
              tool_type: "command_preview",
              operation_name: "complete_demo_lend",
              allowed: false,
              denial_reason: inspect(reason)
            })

            %{reply: lend_denied_reply(reason), mode: "command", action: nil}
        end
    end
  end

  defp lend_denied_reply({:ineligible, "loan_fundraising", _}),
    do:
      "That loan is no longer fundraising, so it can't accept new lending. Pick a loan that's still raising funds."

  defp lend_denied_reply({:ineligible, "lend_amount_valid", _}),
    do: "Lending happens in $25 increments — try $25, $50, or $75."

  defp lend_denied_reply(reason),
    do:
      "I can't lend on your behalf right now (#{inspect(reason)}). You may need to sign in as a lender."

  defp find_loan(_locale, query) when query in [nil, ""], do: nil

  defp find_loan(locale, query) do
    q = String.downcase(query)

    Kiva.Lending.list_localized_loans(locale, %{status: "fundraising"})
    |> Enum.find(fn l ->
      String.contains?(String.downcase(l.title || ""), q) or
        String.contains?(String.downcase(l.borrower_name || ""), q)
    end)
  end

  defp ask_portfolio(ctx) do
    if ctx.role == "lender" and ctx.actor do
      s = Kiva.Portfolio.portfolio_summary(ctx.actor.id)
      money = fn c -> Kiva.Localization.format_money(c, "USD", ctx.locale) end

      %{
        reply:
          "You've supported #{s.count} loans, lending #{money.(s.total_cents)}. " <>
            "#{money.(s.returned_cents)} has been repaid; #{money.(s.available_to_relend_cents)} is available to relend.",
        mode: "ask",
        action: nil
      }
    else
      %{reply: "Sign in as a lender to see your impact and repayments.", mode: "ask", action: nil}
    end
  end

  defp lang_name("es"), do: "Español"
  defp lang_name("de"), do: "Deutsch"
  defp lang_name("fr"), do: "Français"
  defp lang_name("nl"), do: "Nederlands"
  defp lang_name(_), do: "English"

  defp stringify(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
