defmodule Kiva.Accounts do
  @moduledoc """
  Identity & access context: users, roles, permission groups, authentication.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Accounts.User

  @doc "Kiva-compat: users by id, order preserved (anonymous/missing ids dropped)."
  def get_users_by_ids([]), do: []

  def get_users_by_ids(ids) do
    by_id = User |> where([u], u.id in ^ids) |> Repo.all() |> Map.new(&{&1.id, &1})
    Enum.flat_map(ids, fn id -> if u = by_id[id], do: [u], else: [] end)
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  @doc """
  Verify email + password, guarding against user-enumeration timing leaks.
  Returns the user or nil.
  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.encrypted_password) ->
        user

      true ->
        Bcrypt.no_user_verify()
        nil
    end
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def list_users, do: Repo.all(from u in User, order_by: u.id)

  def update_user_locale(%User{} = user, locale_code) do
    user
    |> User.profile_changeset(%{default_locale_code: locale_code})
    |> Repo.update()
  end

  @doc "Grant the additive developer capability (API portal access)."
  def enable_developer(%User{} = user) do
    user |> User.profile_changeset(%{developer_enabled: true}) |> Repo.update()
  end

  def set_managed_partner(%User{} = user, partner_id) do
    user
    |> User.profile_changeset(%{managed_partner_id: partner_id})
    |> Repo.update!()
  end
end
