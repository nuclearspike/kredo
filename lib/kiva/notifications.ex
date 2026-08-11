defmodule Kiva.Notifications do
  @moduledoc """
  The lender reveal layer: a notification is a truth routed to a specific actor
  via a surface. Generated when a funded loan reaches 100% or a repayment
  arrives — the reveals the old demo went silent on (StoryTime Law 5).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Notifications.Notification

  def create(user_id, type, title, body, link \\ nil) do
    %Notification{}
    |> Notification.changeset(%{
      user_id: user_id,
      type: type,
      title: title,
      body: body,
      link: link
    })
    |> Repo.insert!()
  end

  def list_for_user(user_id, limit \\ 30) do
    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit
    )
  end

  def unread_count(user_id) do
    Repo.aggregate(
      from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      :count
    )
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(from(n in Notification, where: n.user_id == ^user_id and is_nil(n.read_at)),
      set: [read_at: now]
    )
  end

  @doc "Create a notification for every distinct lender who funded a loan."
  def notify_loan_lenders(loan_id, type, title, body, link \\ nil) do
    lender_ids =
      Repo.all(
        from l in Kiva.Portfolio.Lend,
          where: l.loan_id == ^loan_id and not is_nil(l.user_id),
          distinct: true,
          select: l.user_id
      )

    Enum.each(lender_ids, &create(&1, type, title, body, link))
    length(lender_ids)
  end

  @doc """
  Notify the partner that manages a loan (the user(s) whose `managed_partner_id`
  matches the loan's partner) — used when staff act on a submitted loan.
  """
  def notify_partner(%{partner_id: nil}, _type, _title, _body, _link), do: 0

  def notify_partner(%{partner_id: partner_id}, type, title, body, link) do
    user_ids =
      Repo.all(from u in "users", where: u.managed_partner_id == ^partner_id, select: u.id)

    Enum.each(user_ids, &create(&1, type, title, body, link))
    length(user_ids)
  end
end
