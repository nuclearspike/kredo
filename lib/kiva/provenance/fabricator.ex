defmodule Kiva.Provenance.Fabricator do
  @moduledoc """
  DEMO-ONLY deterministic fabricator for listing provenance history.

  The dataset holds ~1.1M loans, so history is not bulk-seeded. Instead the
  trail for a listing materializes lazily on first staff/admin view
  (`ensure!/1`, advisory-locked so concurrent viewers cannot double-seed) and
  `priv/repo/seeds_provenance.exs` eagerly warms a browse-path slice.
  Deterministic per loan (phash2-seeded); translation events derive from the
  REAL loans_lc rows and every hash is sha256 of actual seeded content, so
  derivation chains genuinely verify. Live command events append afterwards.
  See docs/fractalflow/provenance_subsystem.lssd.md (demo_fabrication_disclosure).
  """
  import Ecto.Query, warn: false
  alias Kiva.{Repo, Provenance}
  alias Kiva.Provenance.Event
  alias Kiva.Lending.Loan

  @officers %{
    "GT" => [{"Marisol Choc", "Cobán"}, {"Diego Tzul", "Quetzaltenango"}],
    "KE" => [{"Brian Otieno", "Kisumu"}, {"Faith Wanjiru", "Nakuru"}],
    "US" => [{"Dana Whitfield", "Nashville, TN"}, {"Marcus Lee", "Memphis, TN"}],
    "PE" => [{"Rosa Quispe", "Cusco"}, {"Jorge Huamán", "Arequipa"}],
    "JO" => [{"Layla Haddad", "Amman"}, {"Omar Nasser", "Irbid"}],
    "UG" => [{"Grace Nakato", "Kampala"}, {"Samuel Okello", "Gulu"}],
    "NL" => [{"Pieter Jansen", "Utrecht"}, {"Femke Visser", "Groningen"}],
    "PH" => [{"Ana Santos", "Cebu"}, {"Miguel Reyes", "Iloilo"}],
    "KH" => [{"Sokha Chan", "Siem Reap"}, {"Dara Pich", "Battambang"}],
    "NI" => [{"Carmen Ortega", "Managua"}, {"Luis Baldizón", "León"}],
    "SN" => [{"Awa Diop", "Dakar"}, {"Mamadou Sall", "Thiès"}],
    "VN" => [{"Linh Tran", "Ho Chi Minh City"}, {"Minh Nguyen", "Da Nang"}],
    "BO" => [{"Julia Mamani", "La Paz"}, {"Carlos Choque", "El Alto"}],
    "EC" => [{"María Cando", "Quito"}, {"Andrés Vera", "Guayaquil"}],
    "RW" => [{"Claudine Uwase", "Kigali"}, {"Eric Habimana", "Musanze"}],
    "TJ" => [{"Zarina Rahimova", "Dushanbe"}, {"Farrukh Nazarov", "Khujand"}]
  }

  @geo %{
    "GT" => {15.47, -90.37, "Alta Verapaz, Guatemala"},
    "KE" => {-0.09, 34.76, "Kisumu County, Kenya"},
    "US" => {36.16, -86.78, "Nashville, TN, USA"},
    "PE" => {-13.53, -71.97, "Cusco, Peru"},
    "JO" => {31.95, 35.93, "Amman, Jordan"},
    "UG" => {0.35, 32.58, "Kampala, Uganda"},
    "NL" => {52.09, 5.12, "Utrecht, Netherlands"},
    "PH" => {10.31, 123.89, "Cebu, Philippines"},
    "KH" => {13.36, 103.86, "Siem Reap, Cambodia"},
    "NI" => {12.13, -86.25, "Managua, Nicaragua"},
    "SN" => {14.72, -17.46, "Dakar, Senegal"},
    "VN" => {10.82, 106.63, "Ho Chi Minh City, Vietnam"},
    "BO" => {-16.5, -68.15, "La Paz, Bolivia"},
    "EC" => {-0.22, -78.51, "Quito, Ecuador"},
    "RW" => {-1.95, 30.06, "Kigali, Rwanda"},
    "TJ" => {38.56, 68.79, "Dushanbe, Tajikistan"}
  }

  @capture_apps [
    {"KredoField", "3.4.1", "Pixel 7a"},
    {"KredoField", "3.2.0", "Galaxy A54"},
    {"OpenCapture", "1.9.2", "iPhone 13"},
    {"KredoField", "3.4.1", "Moto G84"}
  ]

  @translators %{
    "es" => {"Lucía Ferrer", "Sevilla, Spain"},
    "de" => {"Jonas Weber", "Berlin, Germany"},
    "fr" => {"Camille Roy", "Lyon, France"},
    "nl" => {"Sanne de Vries", "Utrecht, Netherlands"},
    "en" => {"Ellen Park", "Portland, OR, USA"}
  }

  @doc "Delete + rebuild the fabricated trail for one loan. Returns the event count."
  def ensure!(loan_id) when is_integer(loan_id) do
    Repo.transaction(fn ->
      # Try-lock: a concurrent fabrication for the same loan must not block a
      # staff page mount — the next view finds the trail present.
      %{rows: [[locked]]} = Repo.query!("SELECT pg_try_advisory_xact_lock(4207, $1)", [loan_id])

      cond do
        not locked -> :busy
        fabricated_count(loan_id) > 0 -> :present
        true -> fabricate!(Repo.get!(Loan, loan_id))
      end
    end)
  end

  defp fabricated_count(loan_id) do
    Repo.aggregate(
      from(e in Event,
        where:
          e.loan_id == ^loan_id and
            fragment("coalesce(?->>'fabricated','false')", e.details) == "true"
      ),
      :count,
      :id
    )
  end

  def fabricate!(loan) do
    loan = Repo.preload(loan, [:translations, :borrower, partner: :translations])

    {:ok, _} =
      Repo.transaction(fn ->
        # Reentrant with ensure!/1's lock; guards seeds-vs-view races too.
        Repo.query!("SELECT pg_advisory_xact_lock(4207, $1)", [loan.id])

        # Live command events are never touched; anything they already cover is
        # not re-fabricated (no duplicate listing.submitted etc.).
        live_covered =
          Repo.all(
            from e in Event,
              where:
                e.loan_id == ^loan.id and
                  fragment("coalesce(?->>'fabricated','false')", e.details) != "true",
              select: {e.event_type, e.subject_ref}
          )
          |> MapSet.new()

        Repo.delete_all(
          from(e in Event,
            where:
              e.loan_id == ^loan.id and
                fragment("coalesce(?->>'fabricated','false')", e.details) == "true"
          )
        )

        build_events(loan, live_covered)
      end)

    Repo.aggregate(from(e in Event, where: e.loan_id == ^loan.id), :count, :id)
  end

  defp build_events(loan, live_covered) do
    {officer, officer_town} = pick(officers(loan.country_code), loan.id, :officer)
    partner_staff = partner_staff_name(loan)
    reviewer = staff_reviewer()
    source_row = Enum.find(loan.translations, & &1.is_source) || List.first(loan.translations)
    base_story = (source_row && (source_row.borrower_story || source_row.title)) || loan.slug
    story_hash = Provenance.sha(base_story)
    reworded? = :erlang.phash2({loan.id, :reword}, 10) < 4

    draft_hash =
      if reworded?, do: Provenance.sha(base_story <> "\n[field draft]"), else: story_hash

    photo? = loan.borrower && loan.borrower.image_url
    photo_hash = photo? && Provenance.sha("photo:" <> loan.borrower.image_url)

    events =
      [
        %{
          subject_type: "site_visit",
          subject_ref: "borrower:#{loan.borrower && loan.borrower.public_id}",
          event_type: "site.visited",
          occurred_at: at(loan, 26, :visit),
          actor_kind: "human",
          actor_name: officer,
          actor_role: "field officer",
          tool: %{app: "KredoField", version: capture_version(loan)},
          location: geo(loan, :visit),
          details: %{note: "Borrower workplace visited near #{officer_town}"}
        },
        %{
          subject_type: "consent",
          subject_ref: "borrower:#{loan.borrower && loan.borrower.public_id}",
          event_type: "consent.recorded",
          occurred_at: at(loan, 21, :consent),
          actor_kind: "human",
          actor_name: officer,
          actor_role: "field officer",
          tool: %{app: "KredoField", version: capture_version(loan)},
          location: geo(loan, :consent),
          content_hash: Provenance.sha("consent:#{loan.borrower && loan.borrower.public_id}"),
          details: %{form: "listing-consent-v3", language: loan.source_locale_code}
        },
        %{
          subject_type: "identity",
          subject_ref: "borrower:#{loan.borrower && loan.borrower.public_id}",
          event_type: "identity.verified",
          occurred_at: at(loan, 20, :identity),
          actor_kind: "human",
          actor_name: partner_staff,
          actor_role: "partner staff",
          details: %{
            method: "national ID + selfie match",
            note: "Checked at the partner branch office"
          }
        },
        %{
          subject_type: "story",
          subject_ref: story_ref(source_row),
          event_type: "story.authored",
          occurred_at: at(loan, 18, :author),
          actor_kind: "human",
          actor_name: partner_staff,
          actor_role: "partner staff",
          source_locale: loan.source_locale_code,
          content_hash: draft_hash,
          details: %{original_language: loan.source_locale_code}
        }
      ] ++
        photo_events(loan, officer, reviewer, photo_hash) ++
        reword_events(loan, source_row, reworded?, draft_hash, story_hash) ++
        story_review_events(loan, reviewer, story_hash) ++
        translation_events(loan, source_row, story_hash, reviewer) ++
        listing_events(loan, partner_staff, reviewer, story_hash) ++
        visibility_events(loan, reviewer, photo?)

    events
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&MapSet.member?(live_covered, {&1.event_type, &1[:subject_ref]}))
    |> Enum.sort_by(& &1.occurred_at, DateTime)
    |> Enum.each(fn attrs ->
      attrs
      |> Map.update(:details, %{fabricated: true}, &Map.put(&1, :fabricated, true))
      |> Map.merge(%{loan_id: loan.id, visibility: Map.get(attrs, :visibility, "admin")})
      |> Provenance.record!()
    end)
  end

  # --- Event group builders --------------------------------------------

  defp photo_events(loan, officer, reviewer, photo_hash) do
    if photo_hash do
      {app, version, device} = pick(@capture_apps, loan.id, :app)

      [
        %{
          subject_type: "photo",
          subject_ref: "photo:#{loan.borrower.image_url}",
          event_type: "photo.captured",
          occurred_at: at(loan, 21, :capture),
          actor_kind: "human",
          actor_name: officer,
          actor_role: "field officer",
          tool: %{app: app, version: version, device: device},
          location: geo(loan, :capture),
          content_hash: photo_hash,
          details: %{consent_on_file: true}
        },
        %{
          subject_type: "photo",
          subject_ref: "photo:#{loan.borrower.image_url}",
          event_type: "photo.uploaded",
          occurred_at: at(loan, 21, :upload),
          actor_kind: "system",
          actor_name: "KredoField sync",
          tool: %{app: app, version: version},
          source_hash: photo_hash,
          content_hash: photo_hash,
          details: %{transport: "mobile sync"}
        },
        %{
          subject_type: "photo",
          subject_ref: "photo:#{loan.borrower.image_url}",
          event_type: "photo.reviewed",
          occurred_at: at(loan, 16, :photo_review),
          actor_kind: "human",
          actor_name: reviewer.name,
          actor_role: reviewer.role,
          actor_user_id: reviewer.id,
          source_hash: photo_hash,
          details: %{checks: ["face visible", "no bystanders", "location plausible"]}
        },
        %{
          subject_type: "photo",
          subject_ref: "photo:#{loan.borrower.image_url}",
          event_type: "photo.approved",
          occurred_at: DateTime.add(at(loan, 16, :photo_review), 7 * 60, :second),
          actor_kind: "human",
          actor_name: reviewer.name,
          actor_role: reviewer.role,
          actor_user_id: reviewer.id,
          source_hash: photo_hash,
          details: %{}
        }
      ]
    else
      []
    end
  end

  defp reword_events(_loan, _row, false, _draft_hash, _story_hash), do: []

  defp reword_events(loan, source_row, true, draft_hash, story_hash) do
    [
      %{
        subject_type: "story",
        subject_ref: story_ref(source_row),
        event_type: "story.ai_reworded",
        occurred_at: at(loan, 17, :reword),
        actor_kind: "ai",
        actor_name: "styleguide-llm",
        actor_role: "story styling model",
        tool: %{provider: "kredo-ai", model: "styleguide-llm-2026.06", template: "warm-story-v2"},
        source_locale: loan.source_locale_code,
        source_hash: draft_hash,
        content_hash: story_hash,
        details: %{
          note: "Grammar and warmth pass; facts unchanged. Field draft not retained in the demo."
        }
      }
    ]
  end

  defp story_review_events(loan, reviewer, story_hash) do
    [
      %{
        subject_type: "story",
        subject_ref: "loan:#{loan.id}",
        event_type: "story.reviewed",
        occurred_at: at(loan, 16, :story_review),
        actor_kind: "human",
        actor_name: reviewer.name,
        actor_role: reviewer.role,
        actor_user_id: reviewer.id,
        source_hash: story_hash,
        details: %{
          checks: ["amounts match application", "no personal identifiers beyond consent"]
        }
      },
      %{
        subject_type: "story",
        subject_ref: "loan:#{loan.id}",
        event_type: "story.approved",
        occurred_at: DateTime.add(at(loan, 16, :story_review), 9 * 60, :second),
        actor_kind: "human",
        actor_name: reviewer.name,
        actor_role: reviewer.role,
        actor_user_id: reviewer.id,
        source_hash: story_hash,
        details: %{}
      }
    ]
  end

  defp translation_events(loan, source_row, story_hash, reviewer) do
    loan.translations
    |> Enum.reject(&(source_row && &1.id == source_row.id))
    |> Enum.flat_map(fn row ->
      text = row.borrower_story || row.title
      content_hash = Provenance.sha(text)
      human? = human_translated?(loan, row)
      {t_name, t_place} = Map.get(@translators, row.locale_code, {"Kredo translator", "remote"})

      produce =
        if human? do
          %{
            subject_type: "translation",
            subject_ref: "loans_lc:#{row.id}",
            event_type: "translation.human",
            occurred_at: row.inserted_at,
            actor_kind: "human",
            actor_name: t_name,
            actor_role: "contract translator",
            tool: %{app: "KredoTranslate", version: "2.1"},
            location: %{place: t_place},
            source_locale: row.source_locale_code || loan.source_locale_code,
            target_locale: row.locale_code,
            source_hash: story_hash,
            content_hash: content_hash,
            details: %{}
          }
        else
          %{
            subject_type: "translation",
            subject_ref: "loans_lc:#{row.id}",
            event_type: "translation.machine",
            occurred_at: row.inserted_at,
            actor_kind: "ai",
            actor_name: "mock-mt",
            actor_role: "machine translator",
            tool: %{provider: "kredo-ai", model: "mock-mt-v0"},
            source_locale: row.source_locale_code || loan.source_locale_code,
            target_locale: row.locale_code,
            source_hash: story_hash,
            content_hash: content_hash,
            details: %{translation_status: row.translation_status}
          }
        end

      review =
        if row.translation_status in ["approved", "published"] do
          %{
            subject_type: "translation",
            subject_ref: "loans_lc:#{row.id}",
            event_type: "translation.approved",
            occurred_at: row.updated_at,
            actor_kind: "human",
            actor_name: reviewer.name,
            actor_role: reviewer.role,
            actor_user_id: reviewer.id,
            target_locale: row.locale_code,
            source_hash: content_hash,
            details: %{}
          }
        else
          if row.translation_status == "rejected" do
            %{
              subject_type: "translation",
              subject_ref: "loans_lc:#{row.id}",
              event_type: "translation.rejected",
              occurred_at: row.updated_at,
              actor_kind: "human",
              actor_name: reviewer.name,
              actor_role: reviewer.role,
              actor_user_id: reviewer.id,
              target_locale: row.locale_code,
              source_hash: content_hash,
              details: %{}
            }
          end
        end

      Enum.reject([produce, review], &is_nil/1)
    end)
  end

  defp listing_events(loan, partner_staff, reviewer, story_hash) do
    submitted = %{
      subject_type: "listing",
      subject_ref: "loan:#{loan.id}",
      event_type: "listing.submitted",
      occurred_at: at(loan, 15, :submit),
      actor_kind: "human",
      actor_name: partner_staff,
      actor_role: "partner staff",
      source_locale: loan.source_locale_code,
      source_hash: story_hash,
      details: %{}
    }

    approved =
      if loan.status in ~w(fundraising funded funded_disbursed repaying delinquent defaulted completed) do
        %{
          subject_type: "listing",
          subject_ref: "loan:#{loan.id}",
          event_type: "listing.approved",
          occurred_at: at(loan, 14, :approve),
          actor_kind: "human",
          actor_name: reviewer.name,
          actor_role: reviewer.role,
          actor_user_id: reviewer.id,
          source_hash: story_hash,
          details: %{}
        }
      end

    Enum.reject([submitted, approved], &is_nil/1)
  end

  defp visibility_events(loan, reviewer, photo?) do
    if photo? && :erlang.phash2({loan.id, :vis}, 9) == 0 do
      [
        %{
          subject_type: "photo",
          subject_ref: "photo:#{loan.borrower.image_url}",
          event_type: "photo.visibility_changed",
          occurred_at:
            DateTime.add(loan.inserted_at, 3 * 86_400 + jit(loan.id, :vis_t, 600) * 60, :second),
          actor_kind: "human",
          actor_name: reviewer.name,
          actor_role: reviewer.role,
          actor_user_id: reviewer.id,
          details: %{
            from: "public",
            to: "lenders_only",
            reason: "Borrower privacy request",
            note: "Requested through the field partner"
          }
        }
      ]
    else
      []
    end
  end

  # --- Deterministic helpers -------------------------------------------

  defp officers(cc), do: Map.get(@officers, cc, [{"Kredo field officer", "the field office"}])

  defp partner_staff_name(loan) do
    case loan.partner && Enum.find(loan.partner.translations, & &1.is_source) do
      %{name: name} when is_binary(name) -> "#{name} staff writer"
      _ -> "Partner staff writer"
    end
  end

  defp staff_reviewer do
    case Kiva.Accounts.get_user_by_email("admin@kredo.test") ||
           Kiva.Accounts.get_user_by_email("admin@kiva.org") do
      nil -> %{id: nil, name: "Ana Reyes", role: "staff"}
      user -> %{id: user.id, name: user.display_name || user.email, role: user.role}
    end
  end

  defp story_ref(nil), do: "loan:unknown"
  defp story_ref(row), do: "loans_lc:#{row.id}"

  defp human_translated?(loan, row),
    do:
      row.translation_status in ["approved", "published"] and
        :erlang.phash2({loan.id, row.locale_code, :m}, 4) == 0

  defp capture_version(loan), do: elem(pick(@capture_apps, loan.id, :app), 1)

  defp pick(list, loan_id, salt), do: Enum.at(list, :erlang.phash2({loan_id, salt}, length(list)))

  defp jit(loan_id, salt, range), do: :erlang.phash2({loan_id, salt}, range)

  # T-minus days with deterministic minute jitter, anchored on the loan row itself.
  defp at(loan, days_before, salt) do
    loan.inserted_at
    |> DateTime.add(-days_before * 86_400 + jit(loan.id, salt, 720) * 60, :second)
    |> DateTime.truncate(:second)
  end

  defp geo(loan, salt) do
    {lat, lng, place} = Map.get(@geo, loan.country_code, {0.0, 0.0, "unknown"})
    dlat = (jit(loan.id, {salt, :lat}, 200) - 100) / 1000.0
    dlng = (jit(loan.id, {salt, :lng}, 200) - 100) / 1000.0
    %{lat: Float.round(lat + dlat, 4), lng: Float.round(lng + dlng, 4), place: place}
  end
end
