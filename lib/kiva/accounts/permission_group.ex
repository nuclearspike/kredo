defmodule Kiva.Accounts.PermissionGroup do
  @moduledoc "A named bundle of permissions assigned to users."
  use Ecto.Schema

  alias Kiva.Accounts.{Permission, User}

  schema "permission_groups" do
    field :key, :string
    field :label, :string

    many_to_many :permissions, Permission,
      join_through: "permission_group_permissions",
      on_replace: :delete

    many_to_many :users, User, join_through: "user_permission_groups"

    timestamps(type: :utc_datetime)
  end
end
