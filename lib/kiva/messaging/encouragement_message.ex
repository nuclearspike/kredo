defmodule Kiva.Messaging.EncouragementMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "encouragement_messages" do
    field :moderation_status, :string, default: "pending"
    field :moderation_reason, :string
    field :source_locale_code, :string, default: "en"
    field :borrower_id, :integer
    field :sender_user_id, :integer
    belongs_to :loan, Kiva.Lending.Loan

    has_many :translations, Kiva.Messaging.EncouragementMessageLc,
      foreign_key: :encouragement_message_id

    timestamps(type: :utc_datetime)
  end

  def changeset(m, attrs) do
    m
    |> cast(attrs, [
      :loan_id,
      :borrower_id,
      :sender_user_id,
      :moderation_status,
      :moderation_reason,
      :source_locale_code
    ])
    |> validate_required([:loan_id])
  end
end
