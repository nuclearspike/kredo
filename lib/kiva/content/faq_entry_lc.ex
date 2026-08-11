defmodule Kiva.Content.FaqEntryLc do
  @moduledoc "Language-content sidecar for a FAQ entry (one row per locale/version)."
  use Ecto.Schema
  import Ecto.Changeset

  alias Kiva.Content.FaqEntry

  schema "faq_entries_lc" do
    field :locale_code, :string
    field :is_source, :boolean, default: false
    field :source_locale_code, :string
    field :question, :string
    field :answer, :string
    field :translation_status, :string, default: "draft"
    field :translated_by_ai_model, :string
    field :translated_from_lc_id, :integer
    field :human_reviewer_user_id, :integer
    field :reviewed_at, :utc_datetime
    field :published_at, :utc_datetime
    field :version, :integer, default: 1
    field :source_hash, :string
    field :field_completeness_score, :float

    belongs_to :faq_entry, FaqEntry

    timestamps(type: :utc_datetime)
  end

  @statuses ~w(draft machine needs_review approved published stale rejected source)
  def statuses, do: @statuses

  def changeset(lc, attrs) do
    lc
    |> cast(attrs, [
      :faq_entry_id,
      :locale_code,
      :is_source,
      :source_locale_code,
      :question,
      :answer,
      :translation_status,
      :translated_by_ai_model,
      :translated_from_lc_id,
      :human_reviewer_user_id,
      :reviewed_at,
      :published_at,
      :version,
      :source_hash,
      :field_completeness_score
    ])
    |> validate_required([:faq_entry_id, :locale_code, :translation_status])
    |> validate_inclusion(:translation_status, @statuses)
  end
end
