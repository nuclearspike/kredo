defmodule Kiva.Translation do
  @moduledoc """
  Translation lifecycle + a **mock** machine translator (no external vendor in
  v1). The important parts are the state machine and the review trail:

      draft -> source_submitted -> machine_translated -> needs_review
            -> approved -> published -> (stale when source changes)

  Machine output is never treated as approved content — it is displayed with a
  clear "machine / needs review" state until a human approves it (Phase 7).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.TranslationRequest

  @mock_model "mock-mt-v0"

  @doc "The mock machine-translation model id stamped on generated rows."
  def mock_model, do: @mock_model

  @doc """
  Mock-translate `text` from `from` into `to`. Deterministic and visibly tagged
  so the demo can show that machine translation happened and from where.
  """
  def machine_translate(nil, _from, _to), do: nil
  def machine_translate("", _from, _to), do: ""

  def machine_translate(text, from, to) when is_binary(text) do
    "[#{to}←#{from}] " <> apply_glossary(text, to)
  end

  # A tiny glossary so a few common words visibly change — enough to read as a
  # translation in the demo without a real MT vendor.
  @glossary %{
    "de" => %{
      "loan" => "Darlehen",
      "lender" => "Kreditgeber",
      "borrower" => "Kreditnehmer",
      "repayment" => "Rückzahlung"
    },
    "es" => %{
      "loan" => "préstamo",
      "lender" => "prestamista",
      "borrower" => "prestatario",
      "repayment" => "reembolso"
    },
    "fr" => %{
      "loan" => "prêt",
      "lender" => "prêteur",
      "borrower" => "emprunteur",
      "repayment" => "remboursement"
    },
    "nl" => %{
      "loan" => "lening",
      "lender" => "geldschieter",
      "borrower" => "lener",
      "repayment" => "terugbetaling"
    }
  }

  defp apply_glossary(text, to) do
    glossary = Map.get(@glossary, to, %{})

    Enum.reduce(glossary, text, fn {en, tr}, acc ->
      Regex.replace(~r/\b#{Regex.escape(en)}\b/i, acc, tr)
    end)
  end

  @doc "Stable content hash for staleness detection when a source changes."
  def source_hash(text) when is_binary(text) do
    :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
  end

  def source_hash(_), do: nil

  # --- Translation requests -------------------------------------------

  def list_translation_requests do
    Repo.all(from r in TranslationRequest, order_by: [desc: r.inserted_at])
  end

  def list_pending_requests do
    Repo.all(from r in TranslationRequest, where: r.status in ["pending", "needs_review"])
  end

  @lc_schemas %{
    "loan" => Kiva.Lending.LoanLc,
    "faq_entry" => Kiva.Content.FaqEntryLc,
    "team_post" => Kiva.Teams.TeamPostLc,
    "encouragement_message" => Kiva.Messaging.EncouragementMessageLc
  }

  @doc "All `*_lc` rows across entity types awaiting human review (machine/needs_review)."
  def list_review_queue do
    build_queue(Kiva.Lending.LoanLc, "loan", :title) ++
      build_queue(Kiva.Content.FaqEntryLc, "faq_entry", :question) ++
      build_queue(Kiva.Teams.TeamPostLc, "team_post", :body) ++
      build_queue(Kiva.Messaging.EncouragementMessageLc, "encouragement_message", :body)
  end

  def review_queue_count do
    [
      Kiva.Lending.LoanLc,
      Kiva.Content.FaqEntryLc,
      Kiva.Teams.TeamPostLc,
      Kiva.Messaging.EncouragementMessageLc
    ]
    |> Enum.map(fn s ->
      Repo.aggregate(
        from(r in s, where: r.translation_status in ["machine", "needs_review"]),
        :count,
        :id
      )
    end)
    |> Enum.sum()
  end

  defp build_queue(schema, type, field) do
    Repo.all(
      from r in schema,
        where: r.translation_status in ["machine", "needs_review"],
        order_by: [desc: r.inserted_at],
        limit: 100
    )
    |> Enum.map(fn r ->
      %{
        entity_type: type,
        lc_id: r.id,
        locale: r.locale_code,
        status: r.translation_status,
        snippet: snippet(Map.get(r, field))
      }
    end)
  end

  defp snippet(nil), do: ""
  defp snippet(s) when is_binary(s), do: String.slice(s, 0, 90)

  @doc """
  Whether a language-content row is still waiting on a reviewer.

  `:awaiting` for machine output and rows flagged for review, `:decided` once a
  reviewer has approved or rejected it. Approving something twice is not a
  second approval, it is a reviewer acting on a stale queue.
  """
  def review_state(entity_type, lc_id) do
    case Map.get(@lc_schemas, entity_type) do
      nil ->
        :unknown_entity_type

      schema ->
        case Repo.get(schema, lc_id) do
          nil -> :missing
          %{translation_status: s} when s in ~w(machine needs_review) -> :awaiting
          _ -> :decided
        end
    end
  end

  @doc "Approve a machine/needs_review LC row (any tracked entity type)."
  def approve(entity_type, lc_id, reviewer_id \\ nil) do
    schema = Map.fetch!(@lc_schemas, entity_type)

    row =
      Repo.get!(schema, lc_id)
      |> Ecto.Changeset.change(translation_status: "approved")
      |> Repo.update!()

    record_review_provenance(entity_type, row, "translation.approved", reviewer_id)
    row
  end

  def reject(entity_type, lc_id, reviewer_id \\ nil) do
    schema = Map.fetch!(@lc_schemas, entity_type)

    row =
      Repo.get!(schema, lc_id)
      |> Ecto.Changeset.change(translation_status: "rejected")
      |> Repo.update!()

    record_review_provenance(entity_type, row, "translation.rejected", reviewer_id)
    row
  end

  # Provenance is loan-scoped: only loan LC reviews land on a listing's trail.
  # Best-effort by design — a provenance failure never fails the review command.
  defp record_review_provenance("loan", row, event_type, reviewer_id) do
    reviewer = reviewer_id && Kiva.Accounts.get_user(reviewer_id)

    Kiva.Provenance.record_side_effect(%{
      loan_id: row.loan_id,
      subject_type: "translation",
      subject_ref: "loans_lc:#{row.id}",
      event_type: event_type,
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
      actor_kind: "human",
      actor_name: (reviewer && (reviewer.display_name || reviewer.email)) || "Staff reviewer",
      actor_role: (reviewer && reviewer.role) || "staff",
      actor_user_id: reviewer_id,
      source_locale: row.source_locale_code,
      target_locale: row.locale_code,
      # Review events derive FROM the reviewed translation content (matches the
      # fabricated grammar), so the chain links back to the produced event.
      source_hash: Kiva.Provenance.sha(row.borrower_story || row.title),
      visibility: "admin",
      details: %{translation_status: row.translation_status}
    })
  end

  defp record_review_provenance(_entity_type, _row, _event_type, _reviewer_id), do: :ok

  @doc "Upsert a translation request for an entity/target pair."
  def upsert_request(attrs) do
    %TranslationRequest{}
    |> TranslationRequest.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:status, :source_locale_code, :updated_at]},
      conflict_target: [:entity_type, :entity_id, :target_locale_code],
      returning: true
    )
  end
end
