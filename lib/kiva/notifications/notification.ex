defmodule Kiva.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [inserted_at: :inserted_at, updated_at: false]
  schema "notifications" do
    field :user_id, :integer
    field :type, :string
    field :title, :string
    field :body, :string
    field :link, :string
    field :read_at, :utc_datetime
    field :inserted_at, :utc_datetime
  end

  def changeset(n, attrs) do
    n
    |> cast(attrs, [:user_id, :type, :title, :body, :link, :read_at])
    |> validate_required([:user_id, :type])
  end
end
