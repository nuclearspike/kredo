defmodule Kiva.Commands.Eligibility do
  @moduledoc """
  Named eligibility checks referenced by command specs. Each returns `:ok` or
  `{:error, reason}`.

  An unrecognised name is refused rather than allowed. A gate is only as good as
  the spelling of its name, and a check that silently passes reads exactly like
  a check that ran: `approve_loan_listing` shipped for months naming a gate that
  no clause matched. `eligibility_checks_test.exs` fails the build if a command
  names a check with no implementation, so this clause should be unreachable.
  """
  import Ecto.Query, only: [from: 2]

  alias Kiva.Borrowers.Borrower
  alias Kiva.Lending.Loan
  alias Kiva.LoanApplications
  alias Kiva.Partners.Partner
  alias Kiva.Repo
  alias Kiva.Teams.Team
  alias Kiva.Trust.Trustee

  @spec check(String.t(), term(), map()) :: :ok | {:error, term()}

  # The acting partner must own the draft loan they are editing/submitting.
  def check("partner_owns_draft", %{managed_partner_id: pid}, params) when not is_nil(pid) do
    case Repo.get(Loan, draft_id(params)) do
      %Loan{partner_id: ^pid} -> :ok
      nil -> {:error, :draft_not_found}
      _ -> {:error, :not_owner}
    end
  end

  def check("partner_owns_draft", _actor, _params), do: {:error, :not_a_partner}

  def check("draft_complete", _actor, params) do
    if LoanApplications.draft_complete?(draft_id(params)),
      do: :ok,
      else: {:error, :draft_incomplete}
  end

  def check("required_lc_source_exists", _actor, params) do
    if LoanApplications.has_source_content?(draft_id(params)),
      do: :ok,
      else: {:error, :missing_source_content}
  end

  def check("partner_review_complete", _actor, params) do
    case Repo.get(Loan, loan_id(params)) do
      %Loan{status: s} when s in ["submitted_to_staff", "staff_review"] -> :ok
      nil -> {:error, :loan_not_found}
      _ -> {:error, :not_submitted_for_review}
    end
  end

  def check("risk_summary_present", _actor, params) do
    loan = Repo.get(Loan, loan_id(params)) |> maybe_preload()
    src = loan && Enum.find(loan.translations, & &1.is_source)

    if src && is_binary(src.risk_summary_public) && String.trim(src.risk_summary_public) != "",
      do: :ok,
      else: {:error, :missing_risk_summary}
  end

  # A listing goes live in every supported language or not at all: publishing
  # one that only reads in some of them puts a borrower's story in front of
  # lenders who cannot read it. The error names the locales still outstanding
  # so the reviewer knows what to clear.
  def check("all_locales_translated", _actor, params) do
    case Kiva.Lending.untranslated_locales(loan_id(params)) do
      [] -> :ok
      {:error, reason} -> {:error, reason}
      pending -> {:error, {:translations_pending, pending}}
    end
  end

  # New lending (basket adds and lends) only flows into fundraising loans.
  def check("loan_fundraising", _actor, params) do
    case Repo.get(Loan, loan_id(params)) do
      nil -> {:error, :loan_not_found}
      %Loan{} = loan -> if Loan.lendable?(loan), do: :ok, else: {:error, :loan_not_fundraising}
    end
  end

  # Lend/basket amounts come in whole $25 units; an omitted or unparseable
  # amount falls back to the handler default ($25), so it passes.
  def check("lend_amount_valid", _actor, params) do
    case lend_amount_cents(params) do
      nil ->
        :ok

      cents ->
        if Kiva.Money.valid_lend_amount?(cents),
          do: :ok,
          else: {:error, :amount_not_in_25_dollar_units}
    end
  end

  # --- target exists ---------------------------------------------------
  #
  # Several handlers reach straight for `Repo.get!` or match on `{:ok, _}`.
  # Without these, a stale id from a queue somebody else already worked is a
  # crash rather than an answer.

  def check("loan_exists", _actor, params) do
    if Repo.exists?(from l in Loan, where: l.id == ^loan_id(params)),
      do: :ok,
      else: {:error, :loan_not_found}
  end

  def check("team_exists", _actor, params) do
    if Repo.exists?(from t in Team, where: t.id == ^int(params["team_id"])),
      do: :ok,
      else: {:error, :team_not_found}
  end

  def check("partner_exists", _actor, params) do
    if Repo.exists?(from p in Partner, where: p.id == ^int(params["partner_id"])),
      do: :ok,
      else: {:error, :partner_not_found}
  end

  def check("trustee_exists", _actor, params) do
    if Repo.exists?(from t in Trustee, where: t.id == ^int(params["trustee_id"])),
      do: :ok,
      else: {:error, :trustee_not_found}
  end

  # --- values the domain actually accepts ------------------------------

  def check("locale_supported", _actor, params) do
    if Kiva.Localization.supported?(params["locale_code"] || params[:locale_code]),
      do: :ok,
      else: {:error, :unsupported_locale}
  end

  # An organization is either trading or it is suspended. Anything else is a
  # typo on its way into a status column that used to accept it.
  def check("org_status_valid", _actor, params) do
    if params["status"] in ~w(active suspended),
      do: :ok,
      else: {:error, {:invalid_status, params["status"]}}
  end

  def check("team_visibility_valid", _actor, params) do
    visibility = params["visibility"] || params[:visibility] || "public"

    if visibility in ~w(public private invite_only),
      do: :ok,
      else: {:error, {:invalid_visibility, visibility}}
  end

  # --- the target is in a state where the action means something -------

  # Repaying a loan with nothing outstanding would either crash or invent an
  # installment. The context reports the same states; asking first lets the
  # preview say so before anyone confirms.
  def check("loan_has_repayment_due", _actor, params) do
    case Repo.get(Loan, loan_id(params)) do
      nil ->
        {:error, :loan_not_found}

      loan ->
        due? =
          Repo.exists?(
            from i in Kiva.Lending.RepaymentScheduleItem,
              join: s in Kiva.Lending.RepaymentSchedule,
              on: s.id == i.repayment_schedule_id,
              where: s.loan_id == ^loan.id and i.status == "scheduled"
          )

        if due?, do: :ok, else: {:error, :no_repayment_due}
    end
  end

  # Money reaches a borrower once.
  #
  # Full funding is deliberately NOT required. Field partners routinely disburse
  # before a loan finishes raising and are repaid by the crowd afterwards, which
  # is why the model carries a direct_disbursal_pending state at all. The loan
  # page offers this action on exactly the same condition: nothing disbursed yet.
  def check("loan_awaiting_disbursal", _actor, params) do
    case Repo.get(Loan, loan_id(params)) do
      nil -> {:error, :loan_not_found}
      %Loan{disbursed_at: nil} -> :ok
      %Loan{} -> {:error, :already_disbursed}
    end
  end

  def check("translation_awaiting_review", _actor, params) do
    case Kiva.Translation.review_state(params["lc_entity_type"], int(params["lc_id"])) do
      :awaiting -> :ok
      :decided -> {:error, :translation_already_reviewed}
      :missing -> {:error, :translation_not_found}
      :unknown_entity_type -> {:error, :unknown_entity_type}
    end
  end

  def check("message_awaiting_moderation", _actor, params) do
    case Kiva.Messaging.moderation_state(int(params["message_id"])) do
      :held -> :ok
      :decided -> {:error, :message_already_moderated}
      :missing -> {:error, :message_not_found}
    end
  end

  # Revoking a permission the user only inherits from their role deletes
  # nothing, and reports success for work that did not happen.
  def check("direct_grant_exists", _actor, params) do
    if Kiva.Permissions.direct_grant?(int(params["user_id"]), params["permission_key"]),
      do: :ok,
      else: {:error, :no_direct_grant}
  end

  # --- the actor stands in the right relationship to the target --------

  def check("actor_manages_partner", %{managed_partner_id: pid}, _params) when not is_nil(pid),
    do: :ok

  def check("actor_manages_partner", _actor, _params), do: {:error, :not_a_partner}

  def check("partner_owns_borrower", %{managed_partner_id: pid}, params)
      when not is_nil(pid) do
    case int(params["borrower_id"] || params[:borrower_id]) do
      # Starting an application without naming a borrower yet is legitimate.
      nil ->
        :ok

      bid ->
        case Repo.get(Borrower, bid) do
          %Borrower{partner_id: ^pid} -> :ok
          nil -> {:error, :borrower_not_found}
          _ -> {:error, :not_owner}
        end
    end
  end

  def check("partner_owns_borrower", _actor, _params), do: {:error, :not_a_partner}

  def check(name, _actor, _params), do: {:error, {:unknown_eligibility_check, name}}

  defp lend_amount_cents(params) do
    case params["amount_cents"] || params[:amount_cents] do
      v when is_binary(v) ->
        case Integer.parse(v) do
          {i, _} -> i
          :error -> nil
        end

      v ->
        v
    end
  end

  defp int(nil), do: nil
  defp int(v) when is_integer(v), do: v

  defp int(v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp draft_id(params), do: params["loan_draft_id"] || params[:loan_draft_id]
  defp loan_id(params), do: params["loan_id"] || params[:loan_id] || draft_id(params)
  defp maybe_preload(nil), do: nil
  defp maybe_preload(loan), do: Repo.preload(loan, :translations)
end
