defmodule KivaWeb.Developer.Docs do
  @moduledoc """
  The developer-documentation model for all three public API surfaces:

    * Platform REST (`/api/v2`)        — our bespoke JSON API, API-key auth
    * Platform GraphQL (`/api/graphql`) — our bespoke GraphQL
    * Kiva Modern GraphQL (`/graphql`)  — Kiva-compatible, OAuth2
    * Kiva Legacy REST (`/v1/*.json`)   — Kiva-compatible, OAuth2

  Endpoints are declared once as specs; `KivaWeb.Developer.CodeGen` renders the
  per-language examples. Prose is wrapped in `gettext/1` so it renders under the
  active locale (es/de/fr/nl) and the `agents.md` view localizes via `?locale=`.
  """
  use Gettext, backend: KivaWeb.Gettext
  alias KivaWeb.Developer.CodeGen

  @doc "The four documented surfaces (id, label, base path, one-line summary)."
  def surfaces do
    [
      %{
        id: :platform_rest,
        name: gettext("Platform REST (v2)"),
        base: "/api/v2",
        summary: gettext("Our bespoke JSON API. Authenticate with an API key.")
      },
      %{
        id: :platform_graphql,
        name: gettext("Platform GraphQL"),
        base: "/api/graphql",
        summary: gettext("Our bespoke GraphQL surface (viewer, loans, and your own data).")
      },
      %{
        id: :kiva_graphql,
        name: gettext("Kiva Modern GraphQL"),
        base: "/graphql",
        summary: gettext("Kiva-compatible GraphQL (lend / my / shop). Authenticate with OAuth2.")
      },
      %{
        id: :kiva_rest,
        name: gettext("Kiva Legacy REST (v1)"),
        base: "/v1",
        summary:
          gettext("Kiva-compatible legacy REST with .json endpoints. OAuth2 for my/* routes.")
      }
    ]
  end

  def surface(id), do: Enum.find(surfaces(), &(&1.id == id))

  def endpoints_for(surface_id), do: Enum.filter(endpoints(), &(&1.surface == surface_id))

  @doc "Every documented endpoint, tagged by surface."
  def endpoints do
    platform_rest() ++ platform_graphql() ++ kiva_graphql() ++ kiva_rest()
  end

  # --- Platform REST (/api/v2) --------------------------------------------
  defp platform_rest do
    [
      %{
        surface: :platform_rest,
        id: "v2_login",
        method: "POST",
        path: "/api/v2/auth/login",
        title: gettext("Log in for a token"),
        auth: :none,
        description:
          gettext("Exchange email + password for a bearer token used by the `me` endpoints."),
        params: [
          p("email", :body, true, gettext("Account email")),
          p("password", :body, true, gettext("Account password"))
        ],
        example: %{body: %{"email" => "lender@kredo.test", "password" => "password"}}
      },
      %{
        surface: :platform_rest,
        id: "v2_loans",
        method: "GET",
        path: "/api/v2/loans",
        title: gettext("List loans"),
        auth: :none,
        description:
          gettext(
            "Localized loan cards. Borrower photos are only returned while a loan is fundraising."
          ),
        params: [
          p("locale", :query, false, gettext("Language code (en/es/de/fr/nl)")),
          p("status", :query, false, gettext("Filter by status")),
          p("country_code", :query, false, gettext("ISO country filter")),
          p("q", :query, false, gettext("Search text"))
        ],
        example: %{query: [{"status", "fundraising"}, {"locale", "es"}]}
      },
      %{
        surface: :platform_rest,
        id: "v2_loan",
        method: "GET",
        path: "/api/v2/loans/rosa-weaving-second-loan",
        title: gettext("Get a loan"),
        auth: :none,
        description: gettext("A single localized loan profile by slug."),
        params: [p("locale", :query, false, gettext("Language code"))],
        example: %{query: [{"locale", "en"}]}
      },
      %{
        surface: :platform_rest,
        id: "v2_me",
        method: "GET",
        path: "/api/v2/me",
        title: gettext("Your account"),
        auth: :api_key,
        description: gettext("The authenticated user behind the API key."),
        params: [],
        example: %{}
      },
      %{
        surface: :platform_rest,
        id: "v2_me_loans",
        method: "GET",
        path: "/api/v2/me/loans",
        title: gettext("Your loans"),
        auth: :api_key,
        description:
          gettext("Loans you have funded (lendings) and, for borrowers, your own loans."),
        params: [p("locale", :query, false, gettext("Language code"))],
        example: %{}
      },
      %{
        surface: :platform_rest,
        id: "v2_me_portfolio",
        method: "GET",
        path: "/api/v2/me/portfolio",
        title: gettext("Your portfolio"),
        auth: :api_key,
        description: gettext("Lending totals: count, amount lent, and amount returned."),
        params: [],
        example: %{}
      }
    ]
  end

  # --- Platform GraphQL (/api/graphql) ------------------------------------
  defp platform_graphql do
    [
      %{
        surface: :platform_graphql,
        id: "pg_loans",
        method: "POST",
        path: "/api/graphql",
        title: gettext("Search loans"),
        auth: :none,
        description: gettext("Localized loan cards via GraphQL."),
        params: [],
        example: %{
          gql: %{
            query:
              "query($loc:String){ localizedLoans(locale:$loc){ slug title fundedPercent borrowerImage } }",
            variables: %{"loc" => "es"}
          }
        }
      },
      %{
        surface: :platform_graphql,
        id: "pg_me",
        method: "POST",
        path: "/api/graphql",
        title: gettext("Your data"),
        auth: :api_key,
        description:
          gettext(
            "The `me` query returns your loans, teams, and portfolio. Works with an API key."
          ),
        params: [],
        example: %{
          gql: %{
            query:
              "{ me { email role lendings { loanSlug amountCents } portfolio { count totalCents } } }"
          }
        }
      }
    ]
  end

  # --- Kiva Modern GraphQL (/graphql) -------------------------------------
  defp kiva_graphql do
    [
      %{
        surface: :kiva_graphql,
        id: "kg_loans",
        method: "POST",
        path: "/graphql",
        title: gettext("lend.loans"),
        auth: :none,
        description: gettext("Kiva-compatible loan search returning the LoanBasic collection."),
        params: [],
        example: %{
          gql: %{
            query:
              "{ lend { loans(filters:{status:fundraising}, limit:2){ totalCount values { id name loanAmount ... on LoanPartner { partnerName } } } } }"
          }
        }
      },
      %{
        surface: :kiva_graphql,
        id: "kg_my",
        method: "POST",
        path: "/graphql",
        title: gettext("my.lender"),
        auth: :oauth,
        description:
          gettext("The authenticated lender profile. Requires an OAuth2 access token."),
        params: [],
        example: %{
          gql: %{
            query:
              "{ my { lender { name loanCount } loans(limit:3){ totalCount values { id name } } } }"
          }
        }
      }
    ]
  end

  # --- Kiva Legacy REST (/v1) ---------------------------------------------
  defp kiva_rest do
    [
      %{
        surface: :kiva_rest,
        id: "k1_search",
        method: "GET",
        path: "/v1/loans/search.json",
        title: gettext("Search loans"),
        auth: :none,
        description: gettext("Legacy loan search with the {paging, loans:[]} envelope."),
        params: [
          p("status", :query, false, gettext("fundraising | funded | all")),
          p("gender", :query, false, gettext("male | female")),
          p("per_page", :query, false, gettext("Page size"))
        ],
        example: %{query: [{"status", "fundraising"}, {"gender", "female"}, {"per_page", "2"}]}
      },
      %{
        surface: :kiva_rest,
        id: "k1_loan",
        method: "GET",
        path: "/v1/loans/1.json",
        title: gettext("Loan detail"),
        auth: :none,
        description: gettext("Batch loan detail by id(s) (comma-separated, up to 100)."),
        params: [],
        example: %{}
      },
      %{
        surface: :kiva_rest,
        id: "k1_token",
        method: "POST",
        path: "/oauth/token",
        title: gettext("Get an access token"),
        auth: :none,
        description:
          gettext(
            "OAuth2 token endpoint. Password grant shown; authorization_code and refresh_token are also supported. Supply client_id + client_secret for a registered app."
          ),
        params: [
          p("grant_type", :body, true, "password"),
          p("username", :body, true, gettext("Account email")),
          p("password", :body, true, gettext("Account password"))
        ],
        example: %{
          body: %{
            "grant_type" => "password",
            "username" => "lender@kredo.test",
            "password" => "password"
          }
        }
      },
      %{
        surface: :kiva_rest,
        id: "k1_my_lender",
        method: "GET",
        path: "/v1/my/lender.json",
        title: gettext("Your lender profile"),
        auth: :oauth,
        description: gettext("The authenticated lender. Requires an OAuth2 bearer token."),
        params: [],
        example: %{}
      }
    ]
  end

  defp p(name, loc, required, desc), do: %{name: name, in: loc, required: required, desc: desc}

  # --- Prose sections (blocks render in the LiveView / markdown) -----------
  def sections do
    [
      %{id: :overview, title: gettext("Overview"), blocks: overview_blocks()},
      %{id: :auth, title: gettext("Authentication"), blocks: auth_blocks()},
      %{id: :locales, title: gettext("Localization"), blocks: locale_blocks()},
      %{id: :errors, title: gettext("Errors"), blocks: error_blocks()}
    ]
  end

  def section(id), do: Enum.find(sections(), &(&1.id == id))

  defp overview_blocks do
    [
      {:p,
       gettext(
         "The Kredo platform exposes three API surfaces. Pick the one that fits your integration:"
       )},
      {:ul,
       [
         gettext(
           "Platform REST (/api/v2) and Platform GraphQL (/api/graphql) — our modern API, authenticated with API keys you create below."
         ),
         gettext(
           "Kiva Modern GraphQL (/graphql) and Kiva Legacy REST (/v1) — drop-in compatible with the real Kiva API, authenticated with OAuth2."
         )
       ]},
      {:note,
       gettext(
         "This is a demo: data is simulated and no real money moves. Rate limits may apply in production."
       )}
    ]
  end

  defp auth_blocks do
    [
      {:h, gettext("API keys (Platform API)")},
      {:p,
       gettext(
         "Create an application in your dashboard, then mint an API key. Send it as a bearer token or in the X-API-Key header. The key is shown once — store it securely."
       )},
      {:code, "bash",
       "curl '#{CodeGen.base_url()}/api/v2/me' \\\n  -H 'Authorization: Bearer kva_live_YOUR_KEY'"},
      {:h, gettext("OAuth2 (Kiva-compatible API)")},
      {:p,
       gettext(
         "Your application doubles as an OAuth2 client: its app ID is the client_id and it has a client secret plus registered redirect URIs. Exchange credentials for an access token, then call the my/* and shop subtrees."
       )},
      {:code, "bash",
       "curl -X POST '#{CodeGen.base_url()}/oauth/token' \\\n  -d 'grant_type=password&username=lender@kredo.test&password=password'"},
      {:note,
       gettext(
         "Secrets (client secret, API key) are displayed only once at creation. Rotate the client secret from the app page if it leaks."
       )}
    ]
  end

  defp locale_blocks do
    [
      {:p,
       gettext(
         "Every read endpoint is localized. Request a language with the locale parameter (REST query string or GraphQL argument)."
       )},
      {:ul,
       [
         gettext("Supported languages: en, es, de, fr, nl."),
         gettext(
           "Resolution order: explicit locale parameter, then session, then your account default, then English."
         ),
         gettext(
           "Unsupported or missing values fall back to English; translated content falls back per-field when a translation is absent."
         )
       ]},
      {:code, "bash", "curl '#{CodeGen.base_url()}/api/v2/loans?locale=fr'"}
    ]
  end

  defp error_blocks do
    [
      {:p,
       gettext(
         "Platform endpoints return errors as {\"errors\": {\"detail\": …}} with a 4xx status (401 unauthorized, 404 not found, 422 invalid)."
       )},
      {:p,
       gettext(
         "Kiva legacy endpoints use the upstream envelope {\"code\": \"org.kiva.<Type>\", \"message\": …}."
       )}
    ]
  end

  # --- Machine-readable reference (agents.md) ------------------------------
  @doc "A complete Markdown reference for AI agents. Caller sets the Gettext locale."
  def agents_markdown do
    [
      "# " <> gettext("Kredo API — agent reference"),
      gettext("Machine-readable reference for the three public API surfaces. Base URL: ") <>
        CodeGen.base_url() <> ".",
      section_markdown(section(:auth)),
      Enum.map_join(surfaces(), "\n\n", &surface_markdown/1),
      section_markdown(section(:locales)),
      section_markdown(section(:errors))
    ]
    |> Enum.join("\n\n")
  end

  defp surface_markdown(surface) do
    header = "## #{surface.name}\n\n#{surface.summary}"

    endpoints =
      Enum.map_join(endpoints_for(surface.id), "\n\n", fn ep ->
        params =
          if ep.params == [],
            do: "",
            else:
              "\n" <>
                Enum.map_join(ep.params, "\n", fn pm ->
                  "- `#{pm.name}` (#{pm.in}#{if pm.required, do: ", required", else: ""}) — #{pm.desc}"
                end)

        "### #{ep.method} #{ep.path}\n#{ep.title} — #{ep.description}#{params}\n\n```bash\n#{CodeGen.render(ep, :curl)}\n```"
      end)

    header <> "\n\n" <> endpoints
  end

  defp section_markdown(%{title: title, blocks: blocks}) do
    "## #{title}\n\n" <> Enum.map_join(blocks, "\n\n", &block_markdown/1)
  end

  defp block_markdown({:p, t}), do: t
  defp block_markdown({:h, t}), do: "### #{t}"
  defp block_markdown({:note, t}), do: "> #{t}"
  defp block_markdown({:ul, items}), do: Enum.map_join(items, "\n", &("- " <> &1))
  defp block_markdown({:code, lang, code}), do: "```#{lang}\n#{code}\n```"
end
