import Config

# Tests never call the real LLM — the assistant uses its deterministic mock.
config :kiva, ai_llm_enabled: false

# Skip the best-effort async API-key usage stamp in tests: the task runs outside
# the Ecto sandbox and would otherwise race with DB-backed tests.
config :kiva, stamp_api_key_usage: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
db_net_opts =
  case System.get_env("PGHOST") do
    nil ->
      [socket_dir: "/tmp"]

    host ->
      [
        hostname: host,
        port: String.to_integer(System.get_env("PGPORT") || "5432"),
        password: System.get_env("PGPASSWORD") || "postgres"
      ]
  end

config :kiva, Kiva.Repo, db_net_opts

config :kiva, Kiva.Repo,
  username: System.get_env("PGUSER") || System.get_env("USER") || "postgres",
  database: "kiva_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  # Pool headroom ABOVE max_cases (schedulers*2) so transient checkout overlap
  # between a finishing and a starting test never queues, plus a generous
  # ownership timeout — together they fix the intermittent
  # "queued and checked out for longer than 15000ms" sandbox flake under load.
  pool_size: System.schedulers_online() * 2 + 8,
  ownership_timeout: 120_000,
  # The actual flake was the pool *checkout* timeout (DBConnection default 15s):
  # under CPU starvation a sandbox owner can't acquire/begin its connection in
  # time. 60s absorbs transient contention while staying well under any real hang.
  timeout: 60_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kiva, KivaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6rOhESv0dSeNI0KRT5Ku0WKPTP1wdxMiB/kOjnNS1W1yxt6uBjj8ptomigjJqymZ",
  server: false

# In test we don't send emails
config :kiva, Kiva.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
