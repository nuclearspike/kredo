defmodule Kiva.Accounts.Role do
  @moduledoc "An actor role: borrower | lender | partner | staff | admin."
  use Ecto.Schema

  schema "roles" do
    field :key, :string
    field :label, :string
    timestamps(type: :utc_datetime)
  end
end
