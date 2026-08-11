defmodule Kiva.Basket do
  @moduledoc """
  A lender's lending basket — assemble lendings across loans, then check out.
  One entry per (user, loan); adding the same loan updates the amount.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Basket.Item

  def add(user_id, loan_id, amount_cents) do
    %Item{}
    |> Item.changeset(%{user_id: user_id, loan_id: loan_id, amount_cents: amount_cents})
    |> Repo.insert!(
      on_conflict: {:replace, [:amount_cents, :updated_at]},
      conflict_target: [:user_id, :loan_id]
    )
  end

  def remove(user_id, loan_id) do
    Repo.delete_all(from b in Item, where: b.user_id == ^user_id and b.loan_id == ^loan_id)
  end

  def clear(user_id), do: Repo.delete_all(from b in Item, where: b.user_id == ^user_id)

  def count(user_id), do: Repo.aggregate(from(b in Item, where: b.user_id == ^user_id), :count)

  def total_cents(user_id) do
    Repo.aggregate(from(b in Item, where: b.user_id == ^user_id), :sum, :amount_cents) || 0
  end

  @doc "Raw basket items (used by checkout)."
  def raw_items(user_id), do: Repo.all(from b in Item, where: b.user_id == ^user_id)

  @doc """
  Lend every basket item through the `complete_demo_lend` command, so all gates
  re-run per item at checkout time. Lent items leave the basket; items whose
  loan is no longer fundraising stay in it and are returned under `:skipped`
  for the caller to surface.
  """
  def checkout(%Kiva.Accounts.User{} = user) do
    results =
      Enum.map(raw_items(user.id), fn item ->
        case Kiva.Commands.execute("complete_demo_lend", user, %{
               "loan_id" => item.loan_id,
               "amount_cents" => item.amount_cents
             }) do
          {:ok, _} ->
            remove(user.id, item.loan_id)
            {:lent, item}

          {:error, _reason} ->
            {:skipped, item}
        end
      end)

    %{
      lent: for({:lent, item} <- results, do: item),
      skipped: for({:skipped, item} <- results, do: item)
    }
  end

  @doc "Localized basket items for display."
  def items(user_id, locale) do
    Repo.all(
      from b in Item,
        where: b.user_id == ^user_id,
        order_by: [desc: b.inserted_at],
        preload: [loan: [:translations, borrower: :translations]]
    )
    |> Enum.map(fn b ->
      loan = b.loan

      title =
        case Resolver.resolve_public(loan.translations, locale).row do
          nil -> loan.slug
          row -> row.title
        end

      borrower =
        loan.borrower &&
          case Resolver.resolve_public(loan.borrower.translations, locale).row do
            nil -> loan.borrower.public_id
            row -> row.display_name
          end

      %{
        loan_id: loan.id,
        slug: loan.slug,
        title: title,
        borrower: borrower,
        amount_cents: b.amount_cents
      }
    end)
  end
end
