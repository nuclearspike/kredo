defmodule Kiva.LoanApplications do
  @moduledoc """
  Partner-facing loan application flow: create/resume a draft loan, capture and
  reuse borrower facts, and submit for staff review. Mutations are invoked
  through `Kiva.Commands` (the single mutation path); this module is the domain
  logic those command handlers call.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Lending.{Loan, LoanLc}
  alias Kiva.Borrowers.Borrower
  alias Kiva.{Localization, Translation, Audit}

  @lc_fields ~w(title short_description borrower_story loan_use repayment_summary risk_summary_public)a

  def list_partner_borrowers(partner_id, cursor \\ nil, limit \\ 24) do
    from(b in Borrower,
      where: b.partner_id == ^partner_id,
      order_by: [desc: b.inserted_at, desc: b.id],
      limit: ^(limit + 1),
      preload: [:translations, sector: :translations, activity: :translations]
    )
    |> partner_borrower_keyset(Kiva.Pagination.decode(cursor))
    |> Repo.all()
  end

  defp partner_borrower_keyset(q, nil), do: q

  defp partner_borrower_keyset(q, {ts, id}),
    do: where(q, [b], b.inserted_at < ^ts or (b.inserted_at == ^ts and b.id < ^id))

  def get_draft(id) do
    Repo.get(Loan, id)
    |> Repo.preload([:translations, borrower: :translations])
  end

  def list_partner_drafts(partner_id) do
    Repo.all(
      from l in Loan,
        where:
          l.partner_id == ^partner_id and
            l.status in ["draft", "submitted_to_staff", "changes_requested"],
        order_by: [desc: l.updated_at],
        preload: [:translations, borrower: :translations]
    )
  end

  @doc "Create a fresh draft for a partner (optionally pre-seeded from a borrower), or resume an open one."
  def create_or_resume_draft(partner_id, borrower_id) do
    base = from l in Loan, where: l.partner_id == ^partner_id and l.status == "draft", limit: 1
    query = if borrower_id, do: where(base, [l], l.borrower_id == ^borrower_id), else: base

    case Repo.one(query) do
      %Loan{} = draft ->
        draft

      nil ->
        borrower = borrower_id && Repo.get(Borrower, borrower_id)

        {:ok, draft} =
          %Loan{}
          |> Loan.changeset(%{
            slug: "draft-#{System.unique_integer([:positive])}",
            status: "draft",
            partner_id: partner_id,
            borrower_id: borrower_id,
            sector_id: borrower && borrower.sector_id,
            activity_id: borrower && borrower.activity_id,
            country_code: borrower && borrower.country_code,
            trust_model: "partner_facilitated",
            source_locale_code: "en",
            loan_amount_cents: 0,
            currency_code: "USD"
          })
          |> Repo.insert()

        draft
    end
  end

  @doc """
  Reuse suggestions for a repeat loan: the borrower's sector/activity/country and
  business summary, plus their most recent loan's terms.
  """
  def reuse_suggestions(%Borrower{} = borrower) do
    borrower =
      Repo.preload(borrower, [:translations, sector: :translations, activity: :translations])

    source_lc =
      Enum.find(borrower.translations, & &1.is_source) || List.first(borrower.translations)

    last_loan =
      Repo.one(
        from l in Loan,
          where: l.borrower_id == ^borrower.id and l.status != "draft",
          order_by: [desc: l.inserted_at],
          limit: 1
      )

    %{
      sector_id: borrower.sector_id,
      activity_id: borrower.activity_id,
      country_code: borrower.country_code,
      business_summary: source_lc && source_lc.business_summary,
      display_name: source_lc && source_lc.display_name,
      prior_amount_cents: last_loan && last_loan.loan_amount_cents,
      prior_term_months: last_loan && last_loan.repayment_term_months
    }
  end

  def reuse_suggestions(_), do: %{}

  @doc "Update a draft's canonical fields and its source language-content row."
  def update_draft(draft_id, params, _actor) do
    case Repo.get(Loan, draft_id) do
      nil ->
        {:error, :draft_not_found}

      draft ->
        {:ok, draft} =
          draft
          |> Loan.changeset(canonical_params(params))
          |> Repo.update()

        upsert_source_lc(draft, params)
        {:ok, draft}
    end
  end

  @doc "Apply a single reuse suggestion to a canonical field."
  def apply_suggestion(draft_id, field_key, value)
      when field_key in ~w(sector_id activity_id country_code trust_model) do
    draft = Repo.get!(Loan, draft_id)
    {:ok, _} = draft |> Loan.changeset(%{field_key => value}) |> Repo.update()
    :ok
  end

  def apply_suggestion(_draft_id, _field_key, _value), do: :ok

  def draft_complete?(draft_id) do
    case get_draft(draft_id) do
      nil ->
        false

      draft ->
        src = source_lc(draft)

        not is_nil(draft.borrower_id) and not is_nil(draft.sector_id) and
          draft.loan_amount_cents > 0 and not is_nil(draft.repayment_term_months) and
          present?(src && src.title) and present?(src && src.borrower_story) and
          present?(src && src.loan_use)
    end
  end

  def has_source_content?(draft_id) do
    case get_draft(draft_id) do
      nil -> false
      draft -> present?((source_lc(draft) || %{title: nil}).title)
    end
  end

  @doc """
  Submit a complete draft for staff review: status -> submitted_to_staff, create
  translation requests for the non-source locales, and record an audit event.
  """
  def submit_for_review(draft_id, actor \\ nil) do
    draft = Repo.get!(Loan, draft_id)

    {:ok, loan} =
      draft
      |> Loan.changeset(%{status: "submitted_to_staff"})
      |> Repo.update()

    src_row =
      Repo.one(
        from lc in LoanLc, where: lc.loan_id == ^loan.id and lc.is_source == true, limit: 1
      )

    story_hash = src_row && Kiva.Provenance.sha(src_row.borrower_story || src_row.title)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if src_row do
      Kiva.Provenance.record_side_effect(%{
        loan_id: loan.id,
        subject_type: "story",
        subject_ref: "loans_lc:#{src_row.id}",
        event_type: "story.authored",
        occurred_at: now,
        actor_kind: "human",
        actor_name: (actor && (actor.display_name || actor.email)) || "Partner staff",
        actor_role: (actor && actor.role) || "partner",
        actor_user_id: actor && actor.id,
        source_locale: loan.source_locale_code,
        content_hash: story_hash,
        visibility: "admin",
        details: %{original_language: loan.source_locale_code}
      })
    end

    Kiva.Provenance.record_side_effect(%{
      loan_id: loan.id,
      subject_type: "listing",
      subject_ref: "loan:#{loan.id}",
      event_type: "listing.submitted",
      occurred_at: now,
      actor_kind: "human",
      actor_name: (actor && (actor.display_name || actor.email)) || "Partner staff",
      actor_role: (actor && actor.role) || "partner",
      actor_user_id: actor && actor.id,
      source_locale: loan.source_locale_code,
      source_hash: story_hash,
      visibility: "admin",
      details: %{}
    })

    for target <- Localization.supported_locales(), target != loan.source_locale_code do
      Translation.upsert_request(%{
        entity_type: "loan",
        entity_id: loan.id,
        source_locale_code: loan.source_locale_code,
        target_locale_code: target,
        status: "pending"
      })
    end

    ensure_risk_summary(loan)
    generate_machine_translations(loan)

    Audit.record(%{
      event_type: "loan.submitted_for_review",
      target_type: "loan",
      target_id: to_string(loan.id),
      summary: "Partner submitted loan ##{loan.id} for review"
    })

    loan
  end

  # Give the loan a public risk summary if the partner left it blank, so it can
  # pass the `risk_summary_present` gate at listing approval.
  defp ensure_risk_summary(%Loan{} = loan) do
    src =
      Repo.one(
        from lc in LoanLc, where: lc.loan_id == ^loan.id and lc.is_source == true, limit: 1
      )

    if src && not present?(src.risk_summary_public) do
      src
      |> Ecto.Changeset.change(
        risk_summary_public: "Reviewed by the field partner; standard repayment terms apply."
      )
      |> Repo.update!()
    end
  end

  # Create machine-translated loans_lc rows (status: machine) for the staff
  # translation review queue — the "create_translation_jobs" side effect.
  defp generate_machine_translations(%Loan{} = loan) do
    src =
      Repo.one(
        from lc in LoanLc, where: lc.loan_id == ^loan.id and lc.is_source == true, limit: 1
      )

    if src do
      from = loan.source_locale_code

      for target <- Localization.supported_locales(), target != from do
        unless Repo.exists?(
                 from lc in LoanLc, where: lc.loan_id == ^loan.id and lc.locale_code == ^target
               ) do
          %LoanLc{}
          |> LoanLc.changeset(%{
            loan_id: loan.id,
            locale_code: target,
            is_source: false,
            source_locale_code: from,
            title: Translation.machine_translate(src.title, from, target),
            short_description: Translation.machine_translate(src.short_description, from, target),
            borrower_story: Translation.machine_translate(src.borrower_story, from, target),
            loan_use: Translation.machine_translate(src.loan_use, from, target),
            repayment_summary: Translation.machine_translate(src.repayment_summary, from, target),
            risk_summary_public:
              Translation.machine_translate(src.risk_summary_public, from, target),
            translated_from_lc_id: src.id,
            translation_status: "machine"
          })
          |> Repo.insert!()
          |> tap(fn row ->
            Kiva.Provenance.record_side_effect(%{
              loan_id: loan.id,
              subject_type: "translation",
              subject_ref: "loans_lc:#{row.id}",
              event_type: "translation.machine",
              occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
              actor_kind: "ai",
              actor_name: "mock-mt",
              actor_role: "machine translator",
              tool: %{provider: "kredo-ai", model: "mock-mt-v0"},
              source_locale: from,
              target_locale: target,
              source_hash: Kiva.Provenance.sha(src.borrower_story || src.title),
              content_hash: Kiva.Provenance.sha(row.borrower_story || row.title),
              visibility: "admin",
              details: %{translation_status: "machine"}
            })
          end)
        end
      end
    end
  end

  # --- helpers ---
  defp source_lc(%Loan{translations: trs, source_locale_code: src}) when is_list(trs) do
    Enum.find(trs, &(&1.locale_code == src and &1.is_source)) ||
      Enum.find(trs, & &1.is_source)
  end

  defp source_lc(_), do: nil

  defp canonical_params(params) do
    %{}
    |> put_int(:loan_amount_cents, params["loan_amount_cents"] || cents(params["amount"]))
    |> put_int(:repayment_term_months, params["term"] || params["repayment_term_months"])
    |> put_int(:sector_id, params["sector_id"])
    |> put_int(:activity_id, params["activity_id"])
    |> put_str(:country_code, params["country_code"])
    |> put_str(:trust_model, params["trust_model"])
    |> put_str(:source_locale_code, params["source_locale_code"])
    |> put_int(:borrower_id, params["borrower_id"])
  end

  defp upsert_source_lc(%Loan{} = draft, params) do
    attrs =
      @lc_fields
      |> Enum.map(fn f -> {f, params[to_string(f)]} end)
      |> Enum.reject(fn {_f, v} -> is_nil(v) end)
      |> Map.new()

    if map_size(attrs) > 0 do
      base = %{
        loan_id: draft.id,
        locale_code: draft.source_locale_code,
        is_source: true,
        source_locale_code: draft.source_locale_code,
        translation_status: "draft",
        version: 1
      }

      %LoanLc{}
      |> LoanLc.changeset(Map.merge(base, attrs))
      |> Repo.insert!(
        on_conflict: {:replace, Map.keys(attrs) ++ [:updated_at]},
        conflict_target: [:loan_id, :locale_code, :version]
      )
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(s) when is_binary(s), do: String.trim(s) != ""
  defp present?(_), do: false

  defp cents(nil), do: nil
  defp cents(""), do: nil

  defp cents(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {f, _} -> round(f * 100)
      :error -> nil
    end
  end

  defp put_int(map, _k, nil), do: map
  defp put_int(map, _k, ""), do: map
  defp put_int(map, k, v) when is_integer(v), do: Map.put(map, k, v)

  defp put_int(map, k, v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> Map.put(map, k, i)
      :error -> map
    end
  end

  defp put_str(map, _k, nil), do: map
  defp put_str(map, _k, ""), do: map
  defp put_str(map, k, v), do: Map.put(map, k, v)
end
