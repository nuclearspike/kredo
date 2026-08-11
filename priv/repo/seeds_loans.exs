# Seeds 200 demo loans (varied states + matching images + 5-locale content),
# lendings (portfolios / social proof / team feeds), and populated team boards.
# Reads the generated params/content/posts JSON. Run: mix run priv/repo/seeds_loans.exs
import Ecto.Query
alias Kiva.{Repo, Accounts, Partners, Lending, Taxonomy}
alias Kiva.Borrowers.{Borrower, BorrowerLc}
alias Kiva.Lending.RepaymentScheduleItem
alias Kiva.Portfolio.Lend
alias Kiva.Teams.{Team, TeamPost, TeamPostLc, TeamMembership}

gen = Path.join([File.cwd!(), "priv/repo/loan_data"])
params = gen |> Path.join("params.json") |> File.read!() |> Jason.decode!()
content = gen |> Path.join("content.json") |> File.read!() |> Jason.decode!()
team_posts = gen |> Path.join("team_posts.json") |> File.read!() |> Jason.decode!()

today = Date.utc_today()
now = DateTime.utc_now() |> DateTime.truncate(:second)
locs = ~w(en es de fr nl)
:rand.seed(:exsss, {7, 11, 13})
past = fn days -> DateTime.add(now, -days * 86_400, :second) |> DateTime.truncate(:second) end

IO.puts("== seeds_loans: #{length(params)} loans, content for #{map_size(content)} slugs ==")

# ---------- 1. Sectors (13) ----------
sector_names = %{
  "agriculture" => %{"en" => "Agriculture", "es" => "Agricultura", "de" => "Landwirtschaft", "fr" => "Agriculture", "nl" => "Landbouw"},
  "livestock" => %{"en" => "Livestock", "es" => "Ganadería", "de" => "Viehzucht", "fr" => "Élevage", "nl" => "Veeteelt"},
  "retail" => %{"en" => "Retail", "es" => "Comercio", "de" => "Einzelhandel", "fr" => "Commerce", "nl" => "Detailhandel"},
  "food" => %{"en" => "Food", "es" => "Alimentación", "de" => "Lebensmittel", "fr" => "Alimentation", "nl" => "Voeding"},
  "clothing" => %{"en" => "Clothing", "es" => "Ropa", "de" => "Bekleidung", "fr" => "Vêtements", "nl" => "Kleding"},
  "arts" => %{"en" => "Arts", "es" => "Artes", "de" => "Kunsthandwerk", "fr" => "Artisanat", "nl" => "Kunst"},
  "services" => %{"en" => "Services", "es" => "Servicios", "de" => "Dienstleistungen", "fr" => "Services", "nl" => "Diensten"},
  "manufacturing" => %{"en" => "Manufacturing", "es" => "Manufactura", "de" => "Fertigung", "fr" => "Fabrication", "nl" => "Productie"},
  "health" => %{"en" => "Health", "es" => "Salud", "de" => "Gesundheit", "fr" => "Santé", "nl" => "Gezondheid"},
  "education" => %{"en" => "Education", "es" => "Educación", "de" => "Bildung", "fr" => "Éducation", "nl" => "Onderwijs"},
  "construction" => %{"en" => "Construction", "es" => "Construcción", "de" => "Bauwesen", "fr" => "Construction", "nl" => "Bouw"},
  "transportation" => %{"en" => "Transportation", "es" => "Transporte", "de" => "Transport", "fr" => "Transport", "nl" => "Transport"},
  "technology" => %{"en" => "Technology", "es" => "Tecnología", "de" => "Technologie", "fr" => "Technologie", "nl" => "Technologie"}
}

sector_id =
  for {key, names} <- sector_names, into: %{} do
    s = Taxonomy.upsert_sector(key)

    for {loc, name} <- names do
      Taxonomy.upsert_sector_lc(%{
        sector_id: s.id, locale_code: loc, is_source: loc == "en",
        source_locale_code: "en", name: name,
        translation_status: if(loc == "en", do: "published", else: "approved")
      })
    end

    {key, s.id}
  end

# ---------- 2. Partners (new MFIs; keep existing rich ones untouched) ----------
psummary = %{
  "en" => "A local field partner supporting entrepreneurs with fair microloans.",
  "es" => "Un socio local que apoya a emprendedores con microcréditos justos.",
  "de" => "Ein lokaler Partner, der Unternehmer mit fairen Mikrokrediten unterstützt.",
  "fr" => "Un partenaire local qui soutient les entrepreneurs avec des microcrédits équitables.",
  "nl" => "Een lokale partner die ondernemers steunt met eerlijke microkredieten."
}
existing_partner_slugs = ~w(community-loom-cooperative green-fields-microfinance austin-community-trust-hub)
partner_imgs = ~w(/images/partners/community-loom.jpg /images/partners/green-fields.jpg /images/partners/austin.jpg)

partner_id =
  params
  |> Enum.map(&{&1["partner_slug"], &1["partner_name"], &1["country_code"]})
  |> Enum.uniq_by(&elem(&1, 0))
  |> Enum.with_index()
  |> Enum.into(%{}, fn {{slug, name, cc}, idx} ->
    id =
      if slug in existing_partner_slugs do
        Repo.get_by!(Kiva.Partners.Partner, slug: slug).id
      else
        p =
          Partners.upsert_partner(%{
            slug: slug, country_code: cc, trust_model: "partner_facilitated",
            status: "active", image_url: Enum.at(partner_imgs, rem(idx, 3)), default_locale_code: "en"
          })

        for loc <- locs do
          Partners.upsert_partner_lc(%{
            partner_id: p.id, locale_code: loc, is_source: loc == "en", source_locale_code: "en",
            name: name, summary: psummary[loc], profile: psummary[loc],
            translation_status: if(loc == "en", do: "published", else: "approved")
          })
        end

        p.id
      end

    {slug, id}
  end)

IO.puts("   sectors: #{map_size(sector_id)}, partners: #{map_size(partner_id)}")

# ---------- 3. Lender pool ----------
lender_display = ["Avery Stone", "Priya Nair", "Tomas Berg", "Mei Lin", "Sofia Rossi", "Liam O'Brien", "Hana Sato", "Diego Castro", "Nora Haddad", "Felix Weber", "Ada Nwosu"]

main_lender = Accounts.get_user_by_email("lender@kredo.test")

pool_ids =
  for {dn, i} <- Enum.with_index(lender_display) do
    email = "lender#{i + 2}@kredo.test"

    u =
      case Accounts.get_user_by_email(email) do
        nil ->
          {:ok, u} =
            Accounts.register_user(%{
              email: email, password: "password", role: "lender",
              default_locale_code: Enum.at(locs, rem(i, 5)), display_name: dn,
              avatar_url: "/images/lenders/l#{rem(i, 4) + 1}.jpg"
            })

          u

        ex ->
          ex
      end

    u.id
  end

lender_ids = [main_lender.id | pool_ids]
team_ids = Repo.all(from t in Team, select: {t.slug, t.id}) |> Map.new()
all_team_ids = Map.values(team_ids)

# ---------- 4. Loans ----------
fallback = %{"title" => "A microloan", "short_description" => "", "borrower_story" => "", "loan_use" => "", "repayment_summary" => "", "risk_summary_public" => ""}

for {p, idx} <- Enum.with_index(params) do
  slug = p["slug"]
  cc = p["country_code"]
  source = p["source_locale"]
  sector = p["sector"]
  term = p["term_months"]
  amount = p["amount_cents"]
  state = p["state"]
  cdata = content[slug] || %{}
  fields_for = fn loc -> cdata[loc] || cdata["en"] || fallback end

  # borrower
  public_id = "g-" <> slug

  borrower =
    case Repo.get_by(Borrower, public_id: public_id) do
      nil ->
        {:ok, b} =
          %Borrower{}
          |> Borrower.changeset(%{
            public_id: public_id, country_code: cc, preferred_locale_code: source,
            image_url: "/images/loans/#{slug}.jpg", partner_id: partner_id[p["partner_slug"]],
            sector_id: sector_id[sector], activity_id: nil, user_id: nil
          })
          |> Repo.insert()

        b

      ex ->
        ex
    end

  for loc <- locs do
    f = fields_for.(loc)

    Repo.insert!(
      BorrowerLc.changeset(%BorrowerLc{}, %{
        borrower_id: borrower.id, locale_code: loc, is_source: loc == source, source_locale_code: source,
        display_name: p["name"], public_bio: f["borrower_story"], business_summary: f["short_description"],
        translation_status: if(loc == source, do: "published", else: p["ts_nonsource"])
      }),
      on_conflict: {:replace, [:display_name, :public_bio, :business_summary]},
      conflict_target: [:borrower_id, :locale_code, :version]
    )
  end

  # Lending moves in $25 units, so the funded total must too. Floor (not round)
  # keeps a partially-funded fundraising loan from snapping up to fully funded.
  funded =
    cond do
      state == "draft" -> 0
      state == "fundraising" -> Kiva.Money.snap_to_lend_unit(round(amount * p["funded_pct"] / 100))
      true -> amount
    end

  disbursed? = p["disbursed"]
  {fr_start, fr_end} =
    if state == "fundraising",
      do: {past.(:rand.uniform(20)), DateTime.add(now, (5 + :rand.uniform(35)) * 86_400, :second) |> DateTime.truncate(:second)},
      else: {nil, nil}

  loan =
    Lending.upsert_loan(%{
      slug: slug, status: state, partner_id: partner_id[p["partner_slug"]], borrower_id: borrower.id,
      country_code: cc, sector_id: sector_id[sector], activity_id: nil, trust_model: p["trust_model"],
      disbursal_status: if(disbursed?, do: "post_disbursed", else: "pre_disbursed"),
      disbursed_at: if(disbursed?, do: past.(:rand.uniform(120)), else: nil),
      fundraising_started_at: fr_start, fundraising_ends_at: fr_end,
      loan_amount_cents: amount, funded_amount_cents: funded, currency_code: "USD",
      repayment_term_months: term, source_locale_code: source
    })

  for loc <- locs do
    f = fields_for.(loc)

    Lending.upsert_loan_lc(%{
      loan_id: loan.id, locale_code: loc, is_source: loc == source, source_locale_code: source,
      title: f["title"], short_description: f["short_description"], borrower_story: f["borrower_story"],
      loan_use: f["loan_use"], repayment_summary: f["repayment_summary"], risk_summary_public: f["risk_summary_public"],
      translation_status: if(loc == source, do: "published", else: p["ts_nonsource"])
    })
  end

  # repayment schedule (state-appropriate)
  if state != "draft" and is_nil(Repo.preload(loan, :repayment_schedule).repayment_schedule) do
    starts_on = Date.add(today, round(p["start_offset_months"] * 30))
    monthly = max(1000, div(amount, term))
    sched = Lending.create_repayment_schedule(loan.id, starts_on, term, monthly)
    pc = p["paid_count"] || 0

    if pc > 0 do
      from(i in RepaymentScheduleItem, where: i.repayment_schedule_id == ^sched.id, order_by: i.due_on)
      |> Repo.all()
      |> Enum.take(pc)
      |> Enum.each(fn it ->
        it |> Ecto.Changeset.change(status: "paid", paid_on: it.due_on) |> Repo.update!()
      end)
    end
  end

  # lendings (direct insert: no status/funded mutation, no notifications).
  # Split the funded total into whole $25 units so every lend is a valid amount.
  if funded > 0 and not Repo.exists?(from l in Lend, where: l.loan_id == ^loan.id) do
    units = div(funded, 2500)
    n = max(1, min(p["lender_count"] || 1, units))
    per = div(units, n)

    for k <- 1..n do
      amt = (if k == n, do: units - per * (n - 1), else: per) * 2500
      uid = if k == 1 and rem(idx, 3) == 0, do: main_lender.id, else: Enum.random(lender_ids)
      team = if :rand.uniform() < 0.3, do: Enum.random(all_team_ids), else: nil
      Repo.insert!(%Lend{user_id: uid, loan_id: loan.id, amount_cents: amt, lending_team_id: team, inserted_at: past.(:rand.uniform(180))})
    end
  end

  if rem(idx + 1, 50) == 0, do: IO.puts("   ...#{idx + 1} loans")
end

# ---------- 5. Team boards ----------
Repo.all(from lc in TeamPostLc, where: lc.body == "Cheering you on!", select: lc.team_post_id)
|> Enum.uniq()
|> case do
  [] -> :ok
  ids ->
    Repo.delete_all(from lc in TeamPostLc, where: lc.team_post_id in ^ids)
    Repo.delete_all(from p in TeamPost, where: p.id in ^ids)
end

for {slug, posts} <- team_posts, tid = team_ids[slug], not is_nil(tid) do
  existing = Repo.aggregate(from(p in TeamPost, where: p.lending_team_id == ^tid), :count)

  if existing < 4 do
    for {%{"locale" => loc, "body" => body}, j} <- Enum.with_index(posts) do
      dt = past.(j * 4 + :rand.uniform(40))

      post =
        Repo.insert!(%TeamPost{
          lending_team_id: tid, author_user_id: Enum.random(lender_ids),
          moderation_status: "approved", source_locale_code: loc, inserted_at: dt, updated_at: dt
        })

      Repo.insert!(%TeamPostLc{
        team_post_id: post.id, locale_code: loc, is_source: true, source_locale_code: loc,
        body: body, translation_status: "published", inserted_at: dt, updated_at: dt
      })
    end
  end
end

# ---------- 6. Memberships + team totals ----------
for uid <- pool_ids, tid <- Enum.take_random(all_team_ids, :rand.uniform(2)) do
  unless Repo.exists?(from m in TeamMembership, where: m.lending_team_id == ^tid and m.user_id == ^uid) do
    Repo.insert!(%TeamMembership{lending_team_id: tid, user_id: uid, role: "member"})
  end
end

for tid <- all_team_ids do
  total = Repo.aggregate(from(l in Lend, where: l.lending_team_id == ^tid), :sum, :amount_cents) || 0
  mc = Repo.aggregate(from(m in TeamMembership, where: m.lending_team_id == ^tid), :count)
  Repo.get!(Team, tid) |> Ecto.Changeset.change(total_lent_cents: total, member_count: max(1, mc)) |> Repo.update!()
end

IO.puts("== done: loans=#{Repo.aggregate(Kiva.Lending.Loan, :count)} lendings=#{Repo.aggregate(Lend, :count)} posts=#{Repo.aggregate(TeamPost, :count)} ==")
