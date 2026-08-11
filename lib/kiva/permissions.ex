defmodule Kiva.Permissions do
  @moduledoc """
  Permission inspection + management for the admin outlier dashboard. An “outlier”
  is a direct per-user grant (in `user_permissions`) that bypasses the role's
  default group — exactly the thing staff need to notice. `revoke_direct/2` clears
  one (invoked through the `revoke_permission` command).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Accounts.Permission

  def list_outliers do
    Repo.all(
      from up in "user_permissions",
        join: u in "users",
        on: u.id == up.user_id,
        join: p in "permissions",
        on: p.id == up.permission_id,
        order_by: [desc: p.risk_level],
        select: %{
          user_id: u.id,
          email: u.email,
          role: u.role,
          permission: p.key,
          risk: p.risk_level,
          reason: up.reason
        }
    )
  end

  @doc "Revoke a direct per-user permission grant (clears an outlier). Returns {:ok, count}."
  def revoke_direct(user_id, permission_key) do
    case Repo.get_by(Permission, key: permission_key) do
      nil ->
        {:error, :unknown_permission}

      perm ->
        {n, _} =
          Repo.delete_all(
            from up in "user_permissions",
              where: up.user_id == ^user_id and up.permission_id == ^perm.id
          )

        {:ok, n}
    end
  end

  @doc "Grant a direct permission to a user (records the reason; used by seeds/admin)."
  def grant_direct(user_id, permission_key, granted_by_user_id, reason) do
    perm = Repo.get_by!(Permission, key: permission_key)

    Repo.insert_all(
      "user_permissions",
      [
        %{
          user_id: user_id,
          permission_id: perm.id,
          granted_by_user_id: granted_by_user_id,
          reason: reason,
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      ],
      on_conflict: :nothing,
      conflict_target: [:user_id, :permission_id]
    )
  end
end
