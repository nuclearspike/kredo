defmodule Kiva.Provenance.Event do
  @moduledoc "One append-only provenance event on a listing artifact."
  use Ecto.Schema
  import Ecto.Changeset

  @subject_types ~w(photo consent identity site_visit story translation listing)
  @actor_kinds ~w(human ai system)
  @audiences ~w(admin partner lender public)
  @event_types ~w(
    photo.captured photo.uploaded photo.reviewed photo.approved photo.visibility_changed
    consent.recorded identity.verified site.visited
    story.authored story.ai_reworded story.reviewed story.approved
    translation.machine translation.template translation.human
    translation.reviewed translation.approved translation.rejected
    listing.submitted listing.approved
  )

  schema "provenance_events" do
    field :subject_type, :string
    field :subject_ref, :string
    field :event_type, :string
    field :occurred_at, :utc_datetime
    field :actor_kind, :string
    field :actor_name, :string
    field :actor_role, :string
    field :actor_user_id, :integer
    field :tool, :map, default: %{}
    field :location, :map
    field :source_locale, :string
    field :target_locale, :string
    field :source_hash, :string
    field :content_hash, :string
    field :visibility, :string, default: "admin"
    field :details, :map, default: %{}
    belongs_to :loan, Kiva.Lending.Loan
    timestamps(type: :utc_datetime, updated_at: false)
  end

  def subject_types, do: @subject_types
  def event_types, do: @event_types
  def audiences, do: @audiences

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :loan_id,
      :subject_type,
      :subject_ref,
      :event_type,
      :occurred_at,
      :actor_kind,
      :actor_name,
      :actor_role,
      :actor_user_id,
      :tool,
      :location,
      :source_locale,
      :target_locale,
      :source_hash,
      :content_hash,
      :visibility,
      :details
    ])
    |> validate_required([
      :loan_id,
      :subject_type,
      :event_type,
      :occurred_at,
      :actor_kind,
      :actor_name
    ])
    |> validate_inclusion(:subject_type, @subject_types)
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:actor_kind, @actor_kinds)
    |> validate_inclusion(:visibility, @audiences)
    |> foreign_key_constraint(:loan_id)
  end
end
