defmodule Kiva.Audit do
  @moduledoc "Append-only audit trail. Every consequential command writes here."
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Audit.Event

  def record(attrs) do
    %Event{}
    |> Event.changeset(Map.new(attrs))
    |> Repo.insert!()
  end

  def list_events(opts \\ [])
  def list_events(limit) when is_integer(limit), do: list_events(limit: limit)

  def list_events(opts) when is_list(opts) do
    limit = Keyword.get(opts, :limit, 100)

    Event
    |> filter_event_type(Keyword.get(opts, :event_type))
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp filter_event_type(q, t) when t in [nil, ""], do: q
  defp filter_event_type(q, t), do: where(q, [e], ilike(e.event_type, ^"#{t}%"))

  def list_for_target(type, id) do
    Repo.all(
      from e in Event,
        where: e.target_type == ^type and e.target_id == ^to_string(id),
        order_by: [desc: e.inserted_at]
    )
  end
end
