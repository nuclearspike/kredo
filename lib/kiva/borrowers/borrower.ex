defmodule Kiva.Borrowers.Borrower do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :public_id}
  schema "borrowers" do
    field :public_id, :string
    field :country_code, :string
    field :preferred_locale_code, :string, default: "en"
    field :image_url, :string
    # "female" | "male" | "nonbinary" | nil. Backs the Kiva-compat gender filter and
    # the legacy `borrowers[].gender` ("M"/"F") / GraphQL `GenderEnum` serializers.
    field :gender, :string
    field :user_id, :integer
    belongs_to :partner, Kiva.Partners.Partner
    belongs_to :sector, Kiva.Taxonomy.Sector
    belongs_to :activity, Kiva.Taxonomy.Activity
    has_many :translations, Kiva.Borrowers.BorrowerLc, foreign_key: :borrower_id
    timestamps(type: :utc_datetime)
  end

  def changeset(b, attrs) do
    b
    |> cast(attrs, [
      :public_id,
      :country_code,
      :preferred_locale_code,
      :image_url,
      :gender,
      :user_id,
      :partner_id,
      :sector_id,
      :activity_id
    ])
    |> validate_required([:public_id])
    |> unique_constraint(:public_id)
  end
end
