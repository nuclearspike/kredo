defmodule Kiva.Trust.Trustee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trustees" do
    field :slug, :string
    field :country_code, :string
    field :status, :string, default: "active"
    has_many :translations, Kiva.Trust.TrusteeLc, foreign_key: :trustee_id
    timestamps(type: :utc_datetime)
  end

  def changeset(t, attrs) do
    t
    |> cast(attrs, [:slug, :country_code, :status])
    |> validate_required([:slug])
    |> validate_inclusion(:status, ~w(active suspended))
    |> unique_constraint(:slug)
  end
end
