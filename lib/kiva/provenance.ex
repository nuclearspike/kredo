defmodule Kiva.Provenance do
  @moduledoc """
  Append-only listing authenticity trail: who produced, transformed, reviewed,
  and re-scoped every artifact behind a loan listing (photos, consent, identity,
  site visits, story, translations, listing decisions).

  Deliberately exposes no update or delete — a correction is a new event
  referencing the corrected one in `details.correction_of`. Historical demo
  trails are fabricated by `priv/repo/seeds_provenance.exs`; live events ride
  existing command side effects (see `record_side_effect/1`).
  """
  import Ecto.Query, warn: false
  require Logger
  alias Kiva.Repo
  alias Kiva.Provenance.Event

  def record(attrs), do: %Event{} |> Event.changeset(attrs) |> Repo.insert()

  def record!(attrs), do: %Event{} |> Event.changeset(attrs) |> Repo.insert!()

  @doc """
  Best-effort write used inside command side effects: a provenance failure logs
  and never fails the owning command.
  """
  def record_side_effect(attrs) do
    case record(attrs) do
      {:ok, event} ->
        {:ok, event}

      {:error, changeset} ->
        Logger.warning("provenance side-effect write failed: #{inspect(changeset.errors)}")
        :error
    end
  rescue
    # Best-effort by contract: a DB outage or unexpected raise must never fail
    # the owning command (policy live_events_ride_commands).
    e ->
      Logger.warning("provenance side-effect write raised: #{Exception.message(e)}")
      :error
  end

  @doc """
  Demo-only: make sure a listing has its fabricated history before reading it.
  Lazy materialization (advisory-locked) — see `Kiva.Provenance.Fabricator`.
  Best-effort: a fabrication failure logs and returns :error rather than raising
  into the reading surface.
  """
  def ensure_fabricated(loan_id) do
    Kiva.Provenance.Fabricator.ensure!(loan_id)
    :ok
  rescue
    e ->
      Logger.warning("provenance fabrication failed for loan #{loan_id}: #{Exception.message(e)}")
      :error
  end

  @doc "Every event for a listing, oldest first (stable id tie-break)."
  def timeline(loan_id) do
    Repo.all(
      from e in Event,
        where: e.loan_id == ^loan_id,
        order_by: [asc: e.occurred_at, asc: e.id]
    )
  end

  @doc """
  Derivation-chain verdict per event id over a timeline (ordered as returned by
  `timeline/1`): `:origin` (no source hash), `:linked` (source hash matches an
  earlier event's content hash), or `:broken`.
  """
  def chain_status(events) do
    {statuses, _seen} =
      Enum.reduce(events, {%{}, MapSet.new()}, fn e, {acc, seen} ->
        status =
          cond do
            is_nil(e.source_hash) -> :origin
            MapSet.member?(seen, e.source_hash) -> :linked
            true -> :broken
          end

        seen = if e.content_hash, do: MapSet.put(seen, e.content_hash), else: seen
        {Map.put(acc, e.id, status), seen}
      end)

    statuses
  end

  @doc """
  Audience ladder over a list of events. Staff/admin see everything; partners
  see partner/lender/public; lenders see lender/public; everyone else public.
  Only the staff surface renders provenance today — this exists so opening
  visibility later is a policy change, not a data change.
  """
  def visible_events(events, role) when role in ["staff", "admin"], do: events

  def visible_events(events, "partner"),
    do: Enum.filter(events, &(&1.visibility in ["partner", "lender", "public"]))

  def visible_events(events, "lender"),
    do: Enum.filter(events, &(&1.visibility in ["lender", "public"]))

  def visible_events(events, _role), do: Enum.filter(events, &(&1.visibility == "public"))

  @doc "Lowercase hex sha256 of a binary; nil-safe."
  def sha(nil), do: nil

  def sha(text) when is_binary(text),
    do: :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
end
