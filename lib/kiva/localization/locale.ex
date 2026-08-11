defmodule Kiva.Localization.Locale do
  @moduledoc "Supported UI/content locale. Primary key is the locale `code` (e.g. \"es\")."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:code, :string, autogenerate: false}
  @derive {Phoenix.Param, key: :code}
  schema "locales" do
    field :english_name, :string
    field :native_name, :string
    field :enabled, :boolean, default: true
    field :fallback_code, :string
    field :text_direction, :string, default: "ltr"
    field :number_format, :string
    field :currency_format, :string
    field :date_format, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(locale, attrs) do
    locale
    |> cast(attrs, [
      :code,
      :english_name,
      :native_name,
      :enabled,
      :fallback_code,
      :text_direction,
      :number_format,
      :currency_format,
      :date_format
    ])
    |> validate_required([:code, :english_name, :native_name])
  end
end
