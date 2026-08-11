defmodule Kiva.Localization.TranslationRequest do
  @moduledoc "A tracked request to translate one entity into one target locale."
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending machine_translated needs_review completed failed)

  schema "translation_requests" do
    field :entity_type, :string
    field :entity_id, :integer
    field :source_locale_code, :string
    field :target_locale_code, :string
    field :status, :string, default: "pending"
    field :requested_by_user_id, :integer
    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(req, attrs) do
    req
    |> cast(attrs, [
      :entity_type,
      :entity_id,
      :source_locale_code,
      :target_locale_code,
      :status,
      :requested_by_user_id
    ])
    |> validate_required([
      :entity_type,
      :entity_id,
      :source_locale_code,
      :target_locale_code,
      :status
    ])
    |> validate_inclusion(:status, @statuses)
  end
end
