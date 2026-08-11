defmodule Kiva.Content.FaqEntry do
  @moduledoc "Canonical FAQ entry. Actor-facing text lives in `faq_entries_lc`."
  use Ecto.Schema
  import Ecto.Changeset

  alias Kiva.Content.FaqEntryLc

  @derive {Phoenix.Param, key: :slug}
  schema "faq_entries" do
    field :slug, :string
    field :category, :string
    field :position, :integer, default: 0
    field :source_locale_code, :string, default: "en"

    has_many :translations, FaqEntryLc, foreign_key: :faq_entry_id

    timestamps(type: :utc_datetime)
  end

  def changeset(faq, attrs) do
    faq
    |> cast(attrs, [:slug, :category, :position, :source_locale_code])
    |> validate_required([:slug, :source_locale_code])
    |> unique_constraint(:slug)
  end
end
