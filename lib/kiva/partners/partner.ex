defmodule Kiva.Partners.Partner do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}
  schema "partners" do
    field :slug, :string
    field :country_code, :string
    field :default_locale_code, :string, default: "en"
    field :status, :string, default: "active"
    field :trust_model, :string, default: "partner_facilitated"
    field :image_url, :string
    has_many :translations, Kiva.Partners.PartnerLc, foreign_key: :partner_id
    timestamps(type: :utc_datetime)
  end

  def changeset(p, attrs) do
    p
    |> cast(attrs, [:slug, :country_code, :default_locale_code, :status, :trust_model, :image_url])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end
end
