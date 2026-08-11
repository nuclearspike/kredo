defmodule KivaWeb.Router do
  use KivaWeb, :router

  import KivaWeb.UserAuth
  import KivaWeb.ApiAuth
  import KivaWeb.ApiKeyAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KivaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug KivaWeb.Plugs.SetLocale
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_api_key_user
    plug :fetch_api_user
  end

  pipeline :api_authenticated do
    plug :require_api_user
  end

  # Kiva-compatibility REST surface (legacy api.kivaws.org/v1). `.json`/`.xml`
  # suffixes are stripped by `KivaWeb.Plugs.KivaJsonSuffix` in the endpoint.
  pipeline :kiva_v1 do
    plug :accepts, ["json"]
    plug :fetch_api_key_user
    plug :fetch_api_user
  end

  pipeline :graphql do
    # "html" lets the GraphiQL IDE page load in a browser; the JSON API is unaffected.
    plug :accepts, ["json", "html"]
    plug :fetch_session
    plug :fetch_current_user
    plug :fetch_api_key_user
    plug :fetch_api_user
    plug KivaWeb.Plugs.SetLocale
    plug KivaWeb.Plugs.GraphQLContext
  end

  scope "/api" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug, schema: KivaWeb.Schema
  end

  # Kiva-compatibility GraphQL (mirrors the real api.kiva.org/graphql at the root
  # path). Reuses the GraphQL pipeline (session + bearer + locale + context).
  scope "/" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug, schema: KivaWeb.KivaGraphql.Schema
  end

  # Bespoke Platform REST API (v2). Public reads + token/api-key-authenticated
  # `me` surfaces. (v1 is renamed to v2 to avoid colliding with Kiva's real v1.)
  scope "/api/v2", KivaWeb.Api do
    pipe_through :api

    post "/auth/login", AuthController, :login

    get "/loans", LoanController, :index
    get "/loans/:slug", LoanController, :show
    get "/partners/:slug", PartnerController, :show
    get "/teams", TeamController, :index
    get "/teams/:slug", TeamController, :show
    get "/faq", FaqController, :index

    scope "/me" do
      pipe_through :api_authenticated

      get "/", MeController, :show
      get "/loans", MeController, :loans
      get "/teams", MeController, :teams
      get "/portfolio", MeController, :portfolio
    end
  end

  # Kiva-compatibility layer: replicates the REAL Kiva public REST v1 so a migrated
  # site can serve legacy clients (e.g. KivaLens) unchanged. Distinct from our own
  # bespoke `/api/v2` above. Order matters: literal routes before the `:ids` catch.
  scope "/v1", KivaWeb.KivaV1 do
    pipe_through :kiva_v1

    get "/loans/search", LoanController, :search
    get "/loans/newest", LoanController, :newest
    get "/loans/:id/lenders", LoanController, :lenders
    get "/loans/:id/journal_entries", LoanController, :journal_entries
    get "/loans/:ids", LoanController, :show

    get "/partners", PartnerController, :index
    get "/partners/:ids", PartnerController, :show

    get "/lenders/:id/loans", LenderController, :loans
    get "/lenders/:id/teams", LenderController, :teams
    get "/lenders/:ids", LenderController, :show

    get "/teams/search", TeamController, :search
    get "/teams/:id/loans", TeamController, :loans
    get "/teams/:ids", TeamController, :show

    get "/templates/images", TemplatesController, :images

    scope "/my" do
      pipe_through :api_authenticated

      get "/lender", MeController, :lender
      get "/loans", MeController, :loans
      get "/teams", MeController, :teams
      get "/expected_repayments", MeController, :expected_repayments
    end
  end

  # OAuth2-compat (mirrors Kiva's kiva.org/oauth + api.kivaws.org/oauth/token).
  scope "/oauth", KivaWeb.KivaV1 do
    pipe_through :kiva_v1

    get "/authorize", OauthController, :authorize
    post "/token", OauthController, :token
  end

  # Local borrower-photo host. KivaLens requests /img/{size}/{id}.jpg; the real
  # Kiva serves these from its CDN. We generate a deterministic placeholder so the
  # whole stack runs offline. No :accepts pipeline (an <img> request isn't JSON);
  # the global CORSPlug (endpoint.ex) already allows cross-origin image loads.
  scope "/", KivaWeb do
    get "/img/:size/:filename", ImageController, :show
  end

  scope "/", KivaWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
    get "/locale/:locale", LocaleController, :update

    # Developer portal: self-enable + machine-readable docs.
    post "/developers/enable", DeveloperController, :enable
    get "/developers/agents.md", DeveloperController, :agents_md

    # Public / lender-facing
    live_session :public, on_mount: [{KivaWeb.UserAuth, :mount_current_user}] do
      live "/loans", LoanLive.Index, :index
      live "/loans/:slug", LoanLive.Show, :show
      live "/partners/:slug", PartnerLive.Show, :show
      live "/teams", TeamLive.Index, :index
      live "/teams/:slug", TeamLive.Show, :show
      live "/faq", FaqLive, :index
      live "/developers", DevelopersLive, :index
    end

    # Developer management (gated by the additive developer capability).
    live_session :developer, on_mount: [{KivaWeb.UserAuth, :ensure_developer}] do
      live "/developer", Developer.DashboardLive, :index
      live "/developer/apps/:app_id", Developer.AppLive, :show
    end

    # Lender impact
    live_session :lender, on_mount: [{KivaWeb.UserAuth, {:ensure_role, ["lender"]}}] do
      live "/portfolio", PortfolioLive, :index
      live "/basket", BasketLive, :index
    end

    # Notifications — any actor that receives reveals (lenders + partners + staff)
    live_session :notifications,
      on_mount: [{KivaWeb.UserAuth, {:ensure_role, ["lender", "partner", "staff", "admin"]}}] do
      live "/notifications", NotificationsLive, :index
    end

    # Borrower portal
    live_session :borrower, on_mount: [{KivaWeb.UserAuth, {:ensure_role, ["borrower"]}}] do
      live "/portal", PortalLive, :index
    end

    # Partner workspace
    live_session :partner, on_mount: [{KivaWeb.UserAuth, {:ensure_role, ["partner"]}}] do
      live "/partner", PartnerLive, :index
      live "/partner/repayments", Partner.RepaymentsLive, :index
    end

    # Staff / admin operations
    live_session :staff, on_mount: [{KivaWeb.UserAuth, {:ensure_role, ["staff", "admin"]}}] do
      live "/admin", AdminLive, :index
    end
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:kiva, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: KivaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # Self-served modern GraphiQL (well-behaved docs panel + headers tab).
    scope "/", KivaWeb do
      pipe_through :browser
      get "/api/graphiql", DeveloperController, :graphiql
      get "/kiva/graphiql", DeveloperController, :kiva_graphiql
    end
  end
end
