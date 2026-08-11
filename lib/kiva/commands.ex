defmodule Kiva.Commands do
  @moduledoc """
  The command registry — the single, deterministic, audited mutation path.

  **Every** mutation (chat, button, dropdown, bulk action) converges here. The AI
  never writes domain state directly: it can only `preview/3` and, after
  confirmation, `execute/4` a registered command. Each command declares the roles
  allowed, required inputs, eligibility checks, risk level, and side effects
  (mirrors `schemas/command_registry.yaml`).

  Handlers are filled in across phases; unimplemented commands preview correctly
  but return `{:error, {:not_implemented, key}}` on execute.
  """
  alias Kiva.{Audit, Accounts, Localization}

  @registry %{
    "set_locale" => %{
      risk: "low",
      actors: ~w(public borrower lender partner staff admin),
      required: ~w(locale_code),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(update_session_locale maybe_update_user_preference)
    },
    "create_lending_team" => %{
      risk: "medium",
      actors: ~w(lender),
      required: ~w(name source_locale_code visibility),
      preview_required: true,
      confirmation_required: true,
      eligibility: [],
      side_effects: ~w(create_team create_team_lc_source create_translation_requests audit_event)
    },
    "add_loan_to_basket" => %{
      risk: "low",
      actors: ~w(lender),
      required: ~w(loan_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: ~w(loan_fundraising lend_amount_valid),
      side_effects: ~w(upsert_basket_item)
    },
    "complete_demo_lend" => %{
      risk: "medium",
      actors: ~w(lender),
      required: ~w(loan_id),
      preview_required: false,
      confirmation_required: true,
      eligibility: ~w(loan_fundraising lend_amount_valid),
      side_effects: ~w(create_lending increment_funding audit_event)
    },
    "record_repayment" => %{
      risk: "medium",
      actors: ~w(partner staff admin),
      required: ~w(loan_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(mark_item_paid maybe_complete_loan audit_event)
    },
    "post_team_message" => %{
      risk: "low",
      actors: ~w(lender borrower partner staff admin),
      required: ~w(team_id body source_locale_code),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(create_post run_moderation audit_event)
    },
    "submit_encouragement_message" => %{
      risk: "medium",
      actors: ~w(lender),
      required: ~w(loan_id body source_locale_code),
      preview_required: true,
      confirmation_required: true,
      eligibility: [],
      side_effects:
        ~w(create_message run_moderation create_translations_if_approved notify_borrower_if_visible audit_event)
    },
    "advance_demo_time" => %{
      risk: "high",
      actors: ~w(admin),
      required: [],
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects:
        ~w(simulate_funding record_disbursal record_repayment notify_loan_lenders audit_event)
    },
    "set_partner_status" => %{
      risk: "high",
      actors: ~w(admin),
      required: ~w(partner_id status),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(update_partner_status audit_event)
    },
    "set_trustee_status" => %{
      risk: "medium",
      actors: ~w(admin),
      required: ~w(trustee_id status),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(update_trustee_status audit_event)
    },
    "record_disbursal" => %{
      risk: "medium",
      actors: ~w(partner staff admin),
      required: ~w(loan_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects:
        ~w(advance_disbursal_status stamp_disbursed_at notify_loan_lenders audit_event)
    },
    "post_borrower_update" => %{
      risk: "low",
      actors: ~w(partner staff admin),
      required: ~w(loan_id body source_locale_code),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(create_borrower_update notify_loan_lenders audit_event)
    },
    "create_borrower" => %{
      risk: "low",
      actors: ~w(partner),
      required: ~w(name),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(create_borrower create_borrower_lc_source)
    },
    "start_loan_application" => %{
      risk: "low",
      actors: ~w(partner),
      required: [],
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(create_or_resume_draft)
    },
    "save_loan_draft" => %{
      risk: "low",
      actors: ~w(partner),
      required: ~w(loan_draft_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: ~w(partner_owns_draft),
      side_effects: ~w(update_draft_fields update_loan_lc_source)
    },
    "apply_reuse_suggestion" => %{
      risk: "low",
      actors: ~w(partner),
      required: ~w(loan_draft_id field_key suggested_value),
      preview_required: false,
      confirmation_required: false,
      eligibility: ~w(partner_owns_draft),
      side_effects: ~w(update_draft_field audit_event)
    },
    "submit_loan_for_review" => %{
      risk: "high",
      actors: ~w(partner),
      required: ~w(loan_draft_id),
      preview_required: true,
      confirmation_required: true,
      eligibility: ~w(draft_complete partner_owns_draft required_lc_source_exists),
      side_effects:
        ~w(change_status_to_submitted create_staff_review_task create_translation_jobs audit_event)
    },
    "approve_translation" => %{
      risk: "medium",
      actors: ~w(staff admin),
      required: ~w(lc_entity_type lc_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(mark_translation_approved rebuild_read_model audit_event)
    },
    "approve_message" => %{
      risk: "medium",
      actors: ~w(staff admin),
      required: ~w(message_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(override_moderation translate_to_borrower deliver audit_event)
    },
    "reject_message" => %{
      risk: "low",
      actors: ~w(staff admin),
      required: ~w(message_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(confirm_block audit_event)
    },
    "request_loan_changes" => %{
      risk: "medium",
      actors: ~w(staff admin),
      required: ~w(loan_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(change_status_to_changes_requested audit_event)
    },
    "reject_translation" => %{
      risk: "low",
      actors: ~w(staff admin),
      required: ~w(lc_entity_type lc_id),
      preview_required: false,
      confirmation_required: false,
      eligibility: [],
      side_effects: ~w(mark_translation_rejected audit_event)
    },
    "approve_loan_listing" => %{
      risk: "high",
      actors: ~w(staff admin),
      required: ~w(loan_id),
      preview_required: true,
      confirmation_required: true,
      eligibility: ~w(partner_review_complete risk_summary_present all_locales_translated),
      side_effects: ~w(publish_loan rebuild_public_read_models audit_event)
    },
    "revoke_permission" => %{
      risk: "high",
      actors: ~w(admin),
      required: ~w(user_id permission_key),
      preview_required: true,
      confirmation_required: true,
      eligibility: [],
      side_effects: ~w(remove_permission audit_event invalidate_sessions_if_needed)
    }
  }

  def list, do: @registry
  def keys, do: Map.keys(@registry)
  def spec(key), do: Map.get(@registry, key)

  @doc "Commands a given role is permitted to invoke."
  def for_actor(role) do
    role = to_string(role)
    @registry |> Enum.filter(fn {_k, s} -> role in s.actors end) |> Map.new()
  end

  def allowed?(key, role) do
    case spec(key) do
      nil -> false
      s -> to_string(role) in s.actors
    end
  end

  @doc """
  Build a safe preview of a command without mutating anything. Runs role +
  required-input + eligibility checks first.
  """
  def preview(key, actor, params) do
    with {:ok, spec} <- fetch(key),
         :ok <- check_role(spec, actor, key),
         :ok <- check_required(spec, params),
         :ok <- check_eligibility(spec, actor, params) do
      {:ok, build_preview(key, spec, actor, params)}
    end
  end

  @doc """
  Execute a command. Re-runs every gate (preview is advisory, not trusted),
  invokes the deterministic handler, and writes an audit event on success.
  """
  def execute(key, actor, params, _opts \\ []) do
    with {:ok, spec} <- fetch(key),
         :ok <- check_role(spec, actor, key),
         :ok <- check_required(spec, params),
         :ok <- check_eligibility(spec, actor, params),
         {:ok, result} <- run_handler(key, actor, params) do
      Audit.record(%{
        actor_user_id: actor_id(actor),
        actor_role: actor_role(actor),
        event_type: "command.#{key}",
        target_type: result[:target_type],
        target_id: result[:target_id] && to_string(result[:target_id]),
        summary: "Executed #{key}",
        metadata: %{params: redact(params), side_effects: spec.side_effects}
      })

      {:ok, result}
    end
  end

  # --- gates ---------------------------------------------------------
  defp fetch(key) do
    case spec(key) do
      nil -> {:error, :unknown_command}
      s -> {:ok, s}
    end
  end

  defp check_role(spec, actor, key) do
    if actor_role(actor) in spec.actors do
      :ok
    else
      {:error, {:forbidden, key, actor_role(actor)}}
    end
  end

  defp check_required(spec, params) do
    missing =
      Enum.filter(spec.required, fn k ->
        v = params[k] || params[String.to_atom(k)]
        is_nil(v) or v == ""
      end)

    if missing == [], do: :ok, else: {:error, {:missing_inputs, missing}}
  end

  defp check_eligibility(spec, actor, params) do
    Enum.reduce_while(spec.eligibility, :ok, fn check, _acc ->
      case eligible?(check, actor, params) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {:ineligible, check, reason}}}
      end
    end)
  end

  # Named eligibility checks default to :ok until their phase wires real logic.
  defp eligible?(check, actor, params), do: Kiva.Commands.Eligibility.check(check, actor, params)

  defp build_preview(key, spec, actor, params) do
    %{
      command: key,
      risk: spec.risk,
      confirmation_required: spec.confirmation_required,
      side_effects: spec.side_effects,
      params: redact(params),
      summary: summarize(key, actor, params)
    }
  end

  defp summarize("set_locale", _actor, params) do
    code = Localization.normalize(params["locale_code"] || params[:locale_code])
    "Change your language to #{code}."
  end

  defp summarize("create_lending_team", _actor, params),
    do: "Create a new lending team named “#{params["name"] || params[:name]}”."

  defp summarize("submit_encouragement_message", _actor, params),
    do:
      "Send an encouragement message to loan ##{params["loan_id"] || params[:loan_id]} (after moderation)."

  defp summarize(key, _actor, _params), do: "Run #{key}."

  # --- handlers (filled in across phases) ----------------------------
  defp run_handler("set_locale", actor, params) do
    code = Localization.normalize(params["locale_code"] || params[:locale_code])

    case actor do
      %Accounts.User{} = u ->
        {:ok, _} = Accounts.update_user_locale(u, code)
        {:ok, %{locale: code, target_type: "user", target_id: u.id}}

      _ ->
        {:ok, %{locale: code, target_type: "session"}}
    end
  end

  defp run_handler("submit_encouragement_message", %Accounts.User{} = user, params) do
    case Kiva.Messaging.create_encouragement(
           user,
           parse_int(params["loan_id"]),
           params["body"],
           params["source_locale_code"]
         ) do
      {:ok, msg} ->
        {:ok,
         %{
           message_id: msg.id,
           moderation: "approved",
           target_type: "loan",
           target_id: parse_int(params["loan_id"])
         }}

      {:rejected, reason} ->
        {:ok,
         %{
           moderation: "rejected",
           reason: reason,
           target_type: "loan",
           target_id: parse_int(params["loan_id"])
         }}

      {:rewrite, suggestion} ->
        {:ok,
         %{
           moderation: "rewrite",
           suggestion: suggestion,
           target_type: "loan",
           target_id: parse_int(params["loan_id"])
         }}
    end
  end

  defp run_handler("create_lending_team", %Accounts.User{} = user, params) do
    team = Kiva.Teams.create_team(user, params)
    {:ok, %{team_id: team.id, slug: team.slug, target_type: "lending_team", target_id: team.id}}
  end

  defp run_handler("record_repayment", %Accounts.User{} = _user, params) do
    case Kiva.Lending.record_repayment(parse_int(params["loan_id"])) do
      {:ok, item} ->
        {:ok,
         %{
           target_type: "loan",
           target_id: parse_int(params["loan_id"]),
           amount_cents: item.amount_cents
         }}

      other ->
        other
    end
  end

  defp run_handler("add_loan_to_basket", %Accounts.User{} = user, params) do
    amount = parse_int(params["amount_cents"]) || 2500
    Kiva.Basket.add(user.id, parse_int(params["loan_id"]), amount)
    {:ok, %{target_type: "loan", target_id: parse_int(params["loan_id"])}}
  end

  defp run_handler("complete_demo_lend", %Accounts.User{} = user, params) do
    amount = parse_int(params["amount_cents"]) || 2500

    lend =
      Kiva.Portfolio.lend(
        user,
        parse_int(params["loan_id"]),
        amount,
        parse_int(params["team_id"])
      )

    {:ok, %{lend_id: lend.id, target_type: "loan", target_id: lend.loan_id}}
  end

  defp run_handler("post_team_message", %Accounts.User{} = user, params) do
    post =
      Kiva.Teams.add_post(
        parse_int(params["team_id"]),
        user,
        params["body"],
        params["source_locale_code"]
      )

    {:ok,
     %{post_id: post.id, target_type: "lending_team", target_id: parse_int(params["team_id"])}}
  end

  defp run_handler("advance_demo_time", %Accounts.User{} = _user, _params) do
    {:ok, %{target_type: "system", result: Kiva.Lending.advance_demo_time()}}
  end

  defp run_handler("set_partner_status", %Accounts.User{} = user, params) do
    p = Kiva.Partners.set_status(parse_int(params["partner_id"]), params["status"])

    Kiva.Audit.record(%{
      event_type: "partner.status_changed",
      actor_user_id: user.id,
      target_type: "partner",
      target_id: to_string(p.id),
      summary: "Partner #{p.slug} -> #{p.status}"
    })

    {:ok, %{target_type: "partner", target_id: p.id}}
  end

  defp run_handler("set_trustee_status", %Accounts.User{} = user, params) do
    t = Kiva.Trust.set_trustee_status(parse_int(params["trustee_id"]), params["status"])

    Kiva.Audit.record(%{
      event_type: "trustee.status_changed",
      actor_user_id: user.id,
      target_type: "trustee",
      target_id: to_string(t.id),
      summary: "Trustee #{t.slug} -> #{t.status}"
    })

    {:ok, %{target_type: "trustee", target_id: t.id}}
  end

  defp run_handler("revoke_permission", %Accounts.User{} = user, params) do
    uid = parse_int(params["user_id"])
    Kiva.Permissions.revoke_direct(uid, params["permission_key"])

    Kiva.Audit.record(%{
      event_type: "permission.revoked",
      actor_user_id: user.id,
      target_type: "user",
      target_id: to_string(uid),
      summary: "Revoked #{params["permission_key"]} from user ##{uid}"
    })

    {:ok, %{target_type: "user", target_id: uid}}
  end

  defp run_handler("record_disbursal", %Accounts.User{} = _user, params) do
    loan = Kiva.Lending.record_disbursal(parse_int(params["loan_id"]))
    {:ok, %{target_type: "loan", target_id: loan.id, disbursal_status: loan.disbursal_status}}
  end

  defp run_handler("post_borrower_update", %Accounts.User{} = user, params) do
    update =
      Kiva.Updates.post_update(
        user,
        parse_int(params["loan_id"]),
        params["kind"] || "update",
        params["body"],
        params["source_locale_code"]
      )

    {:ok, %{update_id: update.id, target_type: "loan", target_id: parse_int(params["loan_id"])}}
  end

  defp run_handler("create_borrower", %Accounts.User{managed_partner_id: pid} = _u, params)
       when not is_nil(pid) do
    borrower = Kiva.Borrowers.create_borrower(pid, params)
    {:ok, %{borrower_id: borrower.id, target_type: "borrower", target_id: borrower.id}}
  end

  defp run_handler("start_loan_application", %Accounts.User{managed_partner_id: pid} = _u, params)
       when not is_nil(pid) do
    draft =
      Kiva.LoanApplications.create_or_resume_draft(
        pid,
        params["borrower_id"] || params[:borrower_id]
      )

    {:ok, %{draft_id: draft.id, target_type: "loan", target_id: draft.id}}
  end

  defp run_handler("save_loan_draft", actor, params) do
    case Kiva.LoanApplications.update_draft(
           params["loan_draft_id"] || params[:loan_draft_id],
           params,
           actor
         ) do
      {:ok, draft} -> {:ok, %{draft_id: draft.id, target_type: "loan", target_id: draft.id}}
      other -> other
    end
  end

  defp run_handler("apply_reuse_suggestion", _actor, params) do
    id = params["loan_draft_id"] || params[:loan_draft_id]
    Kiva.LoanApplications.apply_suggestion(id, params["field_key"], params["suggested_value"])
    {:ok, %{target_type: "loan", target_id: id}}
  end

  defp run_handler("submit_loan_for_review", actor, params) do
    loan =
      Kiva.LoanApplications.submit_for_review(
        params["loan_draft_id"] || params[:loan_draft_id],
        actor
      )

    {:ok, %{target_type: "loan", target_id: loan.id, status: loan.status}}
  end

  defp run_handler("approve_translation", %Accounts.User{} = user, params) do
    Kiva.Translation.approve(params["lc_entity_type"], parse_int(params["lc_id"]), user.id)
    {:ok, %{target_type: "translation", target_id: params["lc_id"]}}
  end

  defp run_handler("reject_translation", %Accounts.User{} = user, params) do
    Kiva.Translation.reject(params["lc_entity_type"], parse_int(params["lc_id"]), user.id)
    {:ok, %{target_type: "translation", target_id: params["lc_id"]}}
  end

  defp run_handler("approve_message", %Accounts.User{} = _user, params) do
    {:ok, msg} = Kiva.Messaging.approve_message(parse_int(params["message_id"]))
    {:ok, %{target_type: "message", target_id: msg.id}}
  end

  defp run_handler("reject_message", %Accounts.User{} = _user, params) do
    {:ok, msg} = Kiva.Messaging.reject_message(parse_int(params["message_id"]))
    {:ok, %{target_type: "message", target_id: msg.id}}
  end

  defp run_handler("approve_loan_listing", %Accounts.User{} = user, params) do
    case Kiva.Lending.approve_listing(parse_int(params["loan_id"]), user) do
      {:ok, loan} -> {:ok, %{target_type: "loan", target_id: loan.id, status: loan.status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_handler("request_loan_changes", %Accounts.User{} = _user, params) do
    loan = Kiva.Lending.request_changes(parse_int(params["loan_id"]), params["reason"])
    {:ok, %{target_type: "loan", target_id: loan.id, status: loan.status}}
  end

  defp run_handler(key, _actor, _params), do: {:error, {:not_implemented, key}}

  # --- helpers -------------------------------------------------------
  defp actor_role(%Accounts.User{role: role}), do: role
  defp actor_role(%{role: role}), do: to_string(role)
  defp actor_role(_), do: "public"

  defp actor_id(%Accounts.User{id: id}), do: id
  defp actor_id(%{id: id}), do: id
  defp actor_id(_), do: nil

  # Never persist secrets/long bodies verbatim in the audit metadata.
  defp redact(params) do
    params
    |> Map.new(fn {k, v} -> {to_string(k), v} end)
    |> Map.drop(["password", "encrypted_password"])
    |> Enum.map(fn {k, v} -> {k, truncate(v)} end)
    |> Map.new()
  end

  defp truncate(v) when is_binary(v) and byte_size(v) > 200, do: binary_part(v, 0, 200) <> "…"
  defp truncate(v), do: v

  defp parse_int(nil), do: nil
  defp parse_int(i) when is_integer(i), do: i

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> nil
    end
  end
end
