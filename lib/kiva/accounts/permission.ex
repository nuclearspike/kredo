defmodule Kiva.Accounts.Permission do
  @moduledoc "A single capability that can be granted via groups or directly."
  use Ecto.Schema

  schema "permissions" do
    field :key, :string
    field :label, :string
    field :risk_level, :string, default: "low"
    timestamps(type: :utc_datetime)
  end
end
