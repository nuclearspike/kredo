defmodule Kiva.Money do
  @moduledoc """
  The money rules of lending. Every lending amount — a lend, a basket item, a
  loan's requested or funded total — is a whole number of $25 units (2500
  cents), so any aggregate of lending money stays a clean multiple of $25.
  Repayment installments are NOT unit-quantized (they divide the loan total).
  """
  import Ecto.Changeset

  @lend_unit_cents 2500

  @doc "The lending increment: $25 in cents."
  def lend_unit_cents, do: @lend_unit_cents

  @doc "True for a positive whole multiple of the $25 unit."
  def valid_lend_amount?(cents) when is_integer(cents),
    do: cents > 0 and rem(cents, @lend_unit_cents) == 0

  def valid_lend_amount?(_), do: false

  @doc """
  Validates that `field` holds a whole multiple of the $25 unit. Positive by
  default; pass `allow_zero: true` for loan totals (drafts start at 0).
  """
  def validate_lend_amount(changeset, field, opts \\ []) do
    allow_zero = Keyword.get(opts, :allow_zero, false)

    validate_change(changeset, field, fn ^field, cents ->
      cond do
        allow_zero and cents == 0 -> []
        valid_lend_amount?(cents) -> []
        true -> [{field, "must be a positive multiple of $25 (2500 cents)"}]
      end
    end)
  end

  @doc "Floors to a whole number of $25 units (seed/backfill helper)."
  def snap_to_lend_unit(cents) when is_integer(cents),
    do: div(max(cents, 0), @lend_unit_cents) * @lend_unit_cents
end
