# Repoints already-seeded generated borrowers at their unique per-loan image
# (priv/static/images/loans/<slug>.jpg). Only updates where the file exists, so
# any image that failed to generate keeps its current one. Run after the image
# generation completes: mix run priv/repo/update_loan_images.exs
import Ecto.Query
alias Kiva.{Repo, Borrowers.Borrower}

params = "priv/repo/loan_data/params.json" |> File.read!() |> Jason.decode!()

n =
  Enum.reduce(params, 0, fn p, acc ->
    slug = p["slug"]

    if File.exists?("priv/static/images/loans/#{slug}.jpg") do
      {c, _} =
        from(b in Borrower, where: b.public_id == ^("g-" <> slug))
        |> Repo.update_all(set: [image_url: "/images/loans/#{slug}.jpg", updated_at: DateTime.utc_now() |> DateTime.truncate(:second)])

      acc + c
    else
      acc
    end
  end)

IO.puts("repointed #{n} borrowers to per-loan images")
