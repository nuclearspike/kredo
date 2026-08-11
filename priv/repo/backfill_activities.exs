# Populate loans.activity_id so KivaLens (and any legacy client) can show an
# Activity. The bulk loan generators (seeds_loans.exs / build_csv.py) insert
# activity_id = nil while setting sector_id, so nearly every loan serializes
# `activity: null`. This seeds a few real Kiva activities per sector and assigns
# every activity-less loan one, keyed by loan id for variety.
#
# Idempotent + re-runnable (safe after a reseed):
#   mix run priv/repo/backfill_activities.exs
import Ecto.Query
alias Kiva.{Repo, Taxonomy}
alias Kiva.Taxonomy.Sector
alias Kiva.Lending.Loan

# sector key => real Kiva activity names (drawn from KivaLens's own activity list)
sector_activities = %{
  "agriculture" => ["Farming", "Agriculture", "Cattle"],
  "livestock" => ["Livestock", "Poultry", "Dairy"],
  "retail" => ["General Store", "Grocery Store", "Retail"],
  "food" => ["Food Production/Sales", "Bakery", "Restaurant"],
  "clothing" => ["Clothing Sales", "Tailoring", "Used Clothing"],
  "arts" => ["Crafts", "Weaving", "Musical Instruments"],
  "services" => ["Barber Shop", "Beauty Salon", "Cleaning Services"],
  "manufacturing" => ["Manufacturing", "Furniture Making", "Bricks"],
  "health" => ["Health", "Pharmacy", "Medical Clinic"],
  "education" => ["Education provider", "Higher education costs", "Primary/secondary school costs"],
  "construction" => ["Construction", "Construction Supplies", "Carpentry"],
  "transportation" => ["Transportation", "Taxi", "Motorcycle Transport"],
  "technology" => ["Technology", "Mobile Phones", "Computer"]
}

slug = fn name ->
  name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")
end

sectors = Repo.all(from s in Sector, select: {s.key, s.id}) |> Map.new()

total =
  for {skey, names} <- sector_activities, reduce: 0 do
    acc ->
      case sectors[skey] do
        nil ->
          IO.puts("skip #{skey}: no such sector in DB")
          acc

        sid ->
          activity_ids =
            for name <- names do
              a = Taxonomy.upsert_activity(slug.(name), sid)

              Taxonomy.upsert_activity_lc(%{
                activity_id: a.id,
                locale_code: "en",
                is_source: true,
                source_locale_code: "en",
                name: name,
                translation_status: "published"
              })

              a.id
            end

          n = length(activity_ids)

          sector_total =
            activity_ids
            |> Enum.with_index()
            |> Enum.reduce(0, fn {aid, i}, sacc ->
              {count, _} =
                from(l in Loan,
                  where:
                    l.sector_id == ^sid and is_nil(l.activity_id) and
                      fragment("? % ? = ?", l.id, ^n, ^i)
                )
                |> Repo.update_all(set: [activity_id: aid])

              sacc + count
            end)

          IO.puts("#{skey}: #{sector_total} loans across #{n} activities")
          acc + sector_total
      end
  end

null_left = Repo.aggregate(from(l in Loan, where: is_nil(l.activity_id)), :count)
IO.puts("\nBackfilled #{total} loans. Loans still without an activity: #{null_left}")
