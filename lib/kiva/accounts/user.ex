defmodule Kiva.Accounts.User do
  @moduledoc """
  A demo user. `role` is the actor type used for page-context and schema-surface
  scoping. Passwords are bcrypt-hashed; demo seed passwords are intentionally
  weak (`password`) and must never be reused in production.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Kiva.Accounts.PermissionGroup

  @roles ~w(borrower lender partner staff admin)

  schema "users" do
    field :email, :string
    field :encrypted_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :display_name, :string
    field :avatar_url, :string
    field :role, :string, default: "lender"
    field :default_locale_code, :string
    field :managed_partner_id, :integer
    # Additive capability — grants access to the developer portal/API without
    # changing the user's role.
    field :developer_enabled, :boolean, default: false

    many_to_many :permission_groups, PermissionGroup, join_through: "user_permission_groups"

    timestamps(type: :utc_datetime)
  end

  def roles, do: @roles

  @doc "Changeset for registering/seeding a user with a plaintext password."
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :display_name, :avatar_url, :role, :default_locale_code])
    |> validate_required([:email, :password, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+$/)
    |> update_change(:email, &String.downcase/1)
    |> validate_length(:password, min: 4, max: 72)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  @doc "Changeset for non-credential profile changes (e.g. locale preference)."
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :default_locale_code, :managed_partner_id, :developer_enabled])
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    changeset
    |> put_change(:encrypted_password, Bcrypt.hash_pwd_salt(pw))
    |> delete_change(:password)
  end

  defp put_password_hash(changeset), do: changeset
end
