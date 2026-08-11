defmodule KivaWeb.DeveloperController do
  @moduledoc "Self-service developer enablement (additive capability) + machine docs."
  use KivaWeb, :controller

  alias Kiva.Accounts

  @doc "POST /developers/enable — grant the current user the developer capability."
  def enable(conn, _params) do
    case conn.assigns.current_user do
      nil ->
        conn
        |> put_flash(:error, gettext("Please sign in to enable developer access."))
        |> redirect(to: ~p"/login")

      user ->
        {:ok, _user} = Accounts.enable_developer(user)

        conn
        |> put_flash(:info, gettext("Developer access enabled. Welcome to the developer portal."))
        |> redirect(to: ~p"/developer")
    end
  end

  @doc "GET /developers/agents.md — machine-readable API reference for AI agents."
  def agents_md(conn, params) do
    locale = Kiva.Localization.normalize(params["locale"])
    Gettext.put_locale(KivaWeb.Gettext, locale)

    conn
    |> put_resp_content_type("text/markdown")
    |> text(KivaWeb.Developer.Docs.agents_markdown())
  end

  # --- GraphiQL IDE (dev only) --------------------------------------------
  # A self-served modern GraphiQL 3 page — proper docs side-panel + built-in
  # headers tab, and without the sticky hover-tooltip of Absinthe's bundled
  # Playground/GraphiQL interfaces.
  @graphiql_version "3.9.0"

  def graphiql(conn, _params), do: render_graphiql(conn, "/api/graphql", "Platform GraphQL")
  def kiva_graphiql(conn, _params), do: render_graphiql(conn, "/graphql", "Kiva GraphQL")

  defp render_graphiql(conn, endpoint, title) do
    conn |> put_resp_content_type("text/html") |> send_resp(200, graphiql_html(endpoint, title))
  end

  defp graphiql_html(endpoint, title) do
    v = @graphiql_version

    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>#{title} — GraphiQL</title>
        <style>body { margin: 0; } #graphiql { height: 100dvh; }</style>
        <link rel="stylesheet" href="https://unpkg.com/graphiql@#{v}/dist/style.css" />
      </head>
      <body>
        <div id="graphiql">Loading GraphiQL…</div>
        <script src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
        <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
        <script src="https://unpkg.com/graphiql@#{v}/dist/index.umd.js"></script>
        <script>
          const fetcher = GraphiQL.createFetcher({
            url: #{Jason.encode!(endpoint)},
            fetch: (input, init) => fetch(input, Object.assign({}, init, { credentials: "same-origin" }))
          });
          const root = ReactDOM.createRoot(document.getElementById("graphiql"));
          root.render(
            React.createElement(GraphiQL, { fetcher, defaultEditorToolsVisibility: "headers" })
          );
        </script>
      </body>
    </html>
    """
  end
end
