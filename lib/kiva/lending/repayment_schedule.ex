defmodule Kiva.Lending.RepaymentSchedule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "repayment_schedules" do
    field :schedule_type, :string, default: "standard"
    field :starts_on, :date
    field :term_months, :integer
    field :frequency, :string, default: "monthly"
    belongs_to :loan, Kiva.Lending.Loan

    has_many :items, Kiva.Lending.RepaymentScheduleItem,
      foreign_key: :repayment_schedule_id,
      preload_order: [asc: :due_on, asc: :id]

    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:loan_id, :schedule_type, :starts_on, :term_months, :frequency])
    |> validate_required([:loan_id])
  end
end
