defmodule Kiva.ProvenanceTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.{Accounts, Provenance, Translation}
  alias Kiva.Provenance.{Event, Fabricator}

  defp ev(id, source, content) do
    %{id: id, source_hash: source, content_hash: content}
  end

  describe "chain_status/1 (pure)" do
    test "origin, linked, and broken verdicts follow earlier-content linkage" do
      events = [
        ev(1, nil, "aaa"),
        ev(2, "aaa", "bbb"),
        ev(3, "zzz", "ccc"),
        ev(4, "bbb", nil)
      ]

      assert %{1 => :origin, 2 => :linked, 3 => :broken, 4 => :linked} =
               Provenance.chain_status(events)
    end

    test "a source hash matching only a LATER content hash stays broken" do
      events = [ev(1, "future", "aaa"), ev(2, "aaa", "future")]
      assert %{1 => :broken, 2 => :linked} = Provenance.chain_status(events)
    end

    test "an event cannot link to itself even with identical source and content hashes" do
      assert %{1 => :broken} = Provenance.chain_status([ev(1, "same", "same")])
    end

    test "origin wins when source_hash is nil regardless of content matches; duplicates still link" do
      events = [ev(1, nil, "dup"), ev(2, nil, "dup"), ev(3, "dup", "x")]
      assert %{1 => :origin, 2 => :origin, 3 => :linked} = Provenance.chain_status(events)
    end

    test "nil content hashes register nothing and never crash" do
      events = [ev(1, nil, nil), ev(2, "missing", nil)]
      assert %{1 => :origin, 2 => :broken} = Provenance.chain_status(events)
    end
  end

  describe "visible_events/2" do
    setup do
      events =
        for {vis, i} <- Enum.with_index(~w(admin partner lender public)),
            do: %{id: i, visibility: vis}

      %{events: events}
    end

    test "staff and admin see everything", %{events: events} do
      assert Provenance.visible_events(events, "admin") == events
      assert Provenance.visible_events(events, "staff") == events
    end

    test "the ladder narrows per role and preserves order", %{events: events} do
      assert Enum.map(Provenance.visible_events(events, "partner"), & &1.visibility) ==
               ~w(partner lender public)

      assert Enum.map(Provenance.visible_events(events, "lender"), & &1.visibility) ==
               ~w(lender public)

      assert Enum.map(Provenance.visible_events(events, "borrower"), & &1.visibility) ==
               ~w(public)

      assert Enum.map(Provenance.visible_events(events, nil), & &1.visibility) == ~w(public)
    end
  end

  test "record_side_effect swallows invalid attrs without raising" do
    assert :error = Provenance.record_side_effect(%{event_type: "nope"})
    assert :error = Provenance.record_side_effect(%{})
  end

  test "record_side_effect swallows raises from the insert itself (best-effort contract)" do
    %{loan: loan} = loan_fixture()

    # A PID cannot be JSON-encoded, so the insert raises rather than returning
    # a changeset error — the best-effort wrapper must still swallow it.
    assert :error =
             Provenance.record_side_effect(%{
               loan_id: loan.id,
               subject_type: "listing",
               event_type: "listing.submitted",
               occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
               actor_kind: "human",
               actor_name: "raiser",
               details: %{pid: self()}
             })
  end

  describe "live command hooks" do
    setup do
      %{loan: loan, partner: partner} = loan_fixture()

      {:ok, staff} =
        Accounts.register_user(%{
          email: "prov-staff-#{System.unique_integer([:positive])}@kredo.test",
          password: "password",
          role: "staff"
        })

      %{loan: loan, partner: partner, staff: staff}
    end

    test "submit + approve leave listing events with the acting user", %{loan: loan, staff: staff} do
      Kiva.LoanApplications.submit_for_review(loan.id)
      Kiva.Lending.approve_listing(loan.id, staff)

      types = Provenance.timeline(loan.id) |> Enum.map(& &1.event_type)
      assert "listing.submitted" in types
      assert "listing.approved" in types

      approved = Enum.find(Provenance.timeline(loan.id), &(&1.event_type == "listing.approved"))
      assert approved.actor_user_id == staff.id
      assert approved.actor_kind == "human"
    end

    test "loan translation review writes a provenance event with locale and hash", %{
      loan: loan,
      staff: staff
    } do
      row = Enum.find(Kiva.Repo.preload(loan, :translations).translations, &(!&1.is_source))

      Translation.approve("loan", row.id, staff.id)

      assert [event] =
               Provenance.timeline(loan.id)
               |> Enum.filter(&(&1.event_type == "translation.approved"))

      assert event.target_locale == row.locale_code
      assert event.actor_user_id == staff.id
      # Review events derive FROM the reviewed translation (source_hash), matching
      # the fabricated grammar so live chains link.
      assert is_binary(event.source_hash)
    end
  end

  describe "fabricator" do
    test "fabrication is deterministic, chain-valid, and loan-scoped" do
      %{loan: loan} = loan_fixture()
      %{loan: other} = loan_fixture()

      count = Fabricator.fabricate!(loan)
      assert count > 5

      first = Provenance.timeline(loan.id)
      chain = Provenance.chain_status(first)
      refute :broken in Map.values(chain)

      # Re-running rebuilds the same trail and leaves other loans untouched.
      other_count = Fabricator.fabricate!(other)
      assert Fabricator.fabricate!(loan) == count

      second = Provenance.timeline(loan.id)

      assert Enum.map(first, &{&1.event_type, &1.occurred_at, &1.content_hash, &1.actor_name}) ==
               Enum.map(second, &{&1.event_type, &1.occurred_at, &1.content_hash, &1.actor_name})

      assert Kiva.Repo.aggregate(
               from(e in Event, where: e.loan_id == ^other.id),
               :count,
               :id
             ) == other_count
    end

    test "translation events derive from the real LC rows" do
      %{loan: loan} = loan_fixture()
      Fabricator.fabricate!(loan)

      non_source =
        Kiva.Repo.preload(loan, :translations).translations |> Enum.reject(& &1.is_source)

      produced =
        Provenance.timeline(loan.id)
        |> Enum.filter(&(&1.event_type in ["translation.machine", "translation.human"]))

      assert length(produced) == length(non_source)

      assert Enum.sort(Enum.map(produced, & &1.target_locale)) ==
               Enum.sort(Enum.map(non_source, & &1.locale_code))
    end

    test "a loan without borrower photo fabricates no photo events but still verifies" do
      %{loan: loan, borrower: borrower} = loan_fixture()
      assert is_nil(borrower.image_url)

      Fabricator.fabricate!(loan)
      events = Provenance.timeline(loan.id)

      assert Enum.all?(events, &(&1.subject_type != "photo"))
      refute :broken in Map.values(Provenance.chain_status(events))
    end

    test "ensure!/1 materializes once and then reports present" do
      %{loan: loan} = loan_fixture()

      assert {:ok, count} = Fabricator.ensure!(loan.id)
      assert is_integer(count) and count > 0
      assert {:ok, :present} = Fabricator.ensure!(loan.id)
      assert length(Provenance.timeline(loan.id)) == count
    end

    test "live events neither suppress fabrication nor get deleted or duplicated by it" do
      %{loan: loan} = loan_fixture()

      # A live event lands before the first staff view (e.g. partner submits).
      Kiva.LoanApplications.submit_for_review(loan.id)
      live_ids = Provenance.timeline(loan.id) |> Enum.map(& &1.id)
      assert live_ids != []

      # First staff view still materializes the fabricated backstory…
      assert {:ok, count} = Fabricator.ensure!(loan.id)
      assert is_integer(count) and count > length(live_ids)

      events = Provenance.timeline(loan.id)
      # …the live rows survive untouched…
      assert Enum.all?(live_ids, fn id -> Enum.any?(events, &(&1.id == id)) end)
      # …and live-covered event types are not duplicated by fabrication.
      assert Enum.count(events, &(&1.event_type == "listing.submitted")) == 1
      assert Enum.count(events, &(&1.event_type == "story.authored")) == 1

      # Re-fabrication (seed re-run) also preserves the live rows.
      Fabricator.fabricate!(loan)
      after_ids = Provenance.timeline(loan.id) |> Enum.map(& &1.id)
      assert Enum.all?(live_ids, &(&1 in after_ids))
    end

    test "live chains verify end-to-end on a live-born trail" do
      %{loan: loan} = loan_fixture()
      Kiva.LoanApplications.submit_for_review(loan.id)

      events = Provenance.timeline(loan.id)
      chain = Provenance.chain_status(events)
      refute :broken in Map.values(chain)

      # The submit fan-out recorded machine translations with linked hashes.
      assert Enum.any?(events, &(&1.event_type == "translation.machine"))
    end
  end

  describe "database append-only guard" do
    setup do
      %{loan: loan} = loan_fixture()

      {:ok, live} =
        Provenance.record(%{
          loan_id: loan.id,
          subject_type: "listing",
          event_type: "listing.submitted",
          occurred_at: DateTime.utc_now() |> DateTime.truncate(:second),
          actor_kind: "human",
          actor_name: "guard test"
        })

      %{loan: loan, live: live}
    end

    test "updates always raise", %{live: live} do
      # Wrapped in an inner transaction so the PG error rolls back to a
      # savepoint instead of aborting the whole sandbox transaction.
      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        Kiva.Repo.transaction(fn ->
          Kiva.Repo.update_all(from(e in Event, where: e.id == ^live.id),
            set: [actor_name: "tampered"]
          )
        end)
      end
    end

    test "live rows cannot be deleted; fabricated rows can", %{loan: loan, live: live} do
      assert_raise Postgrex.Error, ~r/cannot be deleted/, fn ->
        Kiva.Repo.transaction(fn ->
          Kiva.Repo.delete_all(from(e in Event, where: e.id == ^live.id))
        end)
      end

      Fabricator.fabricate!(loan)

      {deleted, _} =
        Kiva.Repo.delete_all(
          from(e in Event,
            where:
              e.loan_id == ^loan.id and
                fragment("coalesce(?->>'fabricated','false')", e.details) == "true"
          )
        )

      assert deleted > 0
    end
  end
end
