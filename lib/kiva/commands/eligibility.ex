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
  alias Kiva.Repo
  alias Kiva.Lending.Loan
  alias Kiva.LoanApplications

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

  defp draft_id(params), do: params["loan_draft_id"] || params[:loan_draft_id]
  defp loan_id(params), do: params["loan_id"] || params[:loan_id] || draft_id(params)
  defp maybe_preload(nil), do: nil
  defp maybe_preload(loan), do: Repo.preload(loan, :translations)
end
