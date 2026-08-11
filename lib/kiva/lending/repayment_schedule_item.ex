defmodule Kiva.Lending.RepaymentScheduleItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repayment_schedule_items" do
    field :due_on, :date
    field :amount_cents, :integer, default: 0
    field :status, :string, default: "scheduled"
    field :paid_on, :date
    belongs_to :repayment_schedule, Kiva.Lending.RepaymentSchedule
    timestamps(type: :utc_datetime)
  end

  def changeset(i, attrs) do
    i
    |> cast(attrs, [:repayment_schedule_id, :due_on, :amount_cents, :status, :paid_on])
    |> validate_required([:repayment_schedule_id, :due_on, :amount_cents])
  end
end
