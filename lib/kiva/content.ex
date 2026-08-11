defmodule Kiva.Content do
  @moduledoc """
  Public/taxonomy content context. Phase 1 covers localized FAQ entries and is
  the worked example of the `*_lc` sidecar + fallback resolution + on-demand
  machine translation pattern that later entities (loans, partners, teams) reuse.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Content.{FaqEntry, FaqEntryLc}
  alias Kiva.Translation

  @doc "All FAQ entries resolved for `locale`, with fallback metadata per entry."
  def list_localized_faqs(locale) do
    FaqEntry
    |> order_by([f], asc: f.category, asc: f.position)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize_faq(&1, locale))
  end

  def get_faq!(id), do: Repo.get!(FaqEntry, id) |> Repo.preload(:translations)

  def get_faq_by_slug(slug) do
    Repo.get_by(FaqEntry, slug: slug) |> Repo.preload(:translations)
  end

  defp localize_faq(%FaqEntry{} = faq, locale) do
    res = Resolver.resolve_public(faq.translations, locale)

    %{
      faq: faq,
      lc: res.row,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      missing: res.missing,
      status: res.row && res.row.translation_status
    }
  end

  @doc """
  Ensure a machine translation exists for `faq` in `target_locale`. Idempotent:
  returns the existing row if present, otherwise machine-translates from the
  source row, inserts a `machine` sidecar row, and records a translation request.
  This is the on-demand long-tail translation flow.
  """
  def ensure_faq_translation(faq_id, target_locale, requested_by_user_id \\ nil) do
    faq = get_faq!(faq_id)
    target = Kiva.Localization.normalize(target_locale)
    source = Enum.find(faq.translations, & &1.is_source) || hd(faq.translations)

    cond do
      is_nil(source) ->
        {:error, :no_source}

      existing = Enum.find(faq.translations, &(&1.locale_code == target)) ->
        {:ok, existing}

      true ->
        from = source.locale_code

        attrs = %{
          faq_entry_id: faq.id,
          locale_code: target,
          is_source: false,
          source_locale_code: from,
          question: Translation.machine_translate(source.question, from, target),
          answer: Translation.machine_translate(source.answer, from, target),
          translation_status: "machine",
          translated_by_ai_model: Translation.mock_model(),
          translated_from_lc_id: source.id,
          version: 1,
          source_hash: Translation.source_hash(source.question)
        }

        {:ok, row} = %FaqEntryLc{} |> FaqEntryLc.changeset(attrs) |> Repo.insert()

        Translation.upsert_request(%{
          entity_type: "faq_entry",
          entity_id: faq.id,
          source_locale_code: from,
          target_locale_code: target,
          status: "machine_translated",
          requested_by_user_id: requested_by_user_id
        })

        {:ok, row}
    end
  end

  @doc "Approve a machine/needs_review FAQ translation (used by staff in Phase 7)."
  def approve_faq_translation(%FaqEntryLc{} = lc, reviewer_user_id) do
    lc
    |> FaqEntryLc.changeset(%{
      translation_status: "approved",
      human_reviewer_user_id: reviewer_user_id,
      reviewed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      published_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  # --- Authoring helpers (used by seeds) ------------------------------

  def create_faq(attrs), do: %FaqEntry{} |> FaqEntry.changeset(attrs) |> Repo.insert()

  def upsert_faq_lc(attrs) do
    %FaqEntryLc{}
    |> FaqEntryLc.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:question, :answer, :translation_status, :updated_at]},
      conflict_target: [:faq_entry_id, :locale_code, :version]
    )
  end
end
