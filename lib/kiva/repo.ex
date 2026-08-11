defmodule Kiva.Repo do
  use Ecto.Repo,
    otp_app: :kiva,
    adapter: Ecto.Adapters.Postgres
end
