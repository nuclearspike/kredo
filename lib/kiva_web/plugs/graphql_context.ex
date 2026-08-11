defmodule KivaWeb.Plugs.GraphQLContext do
  @moduledoc "Builds the Absinthe context (actor role + locale) from the session."
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    context = %{
      current_user: user,
      actor_role: (user && user.role) || "public",
      locale: conn.assigns[:locale] || "en"
    }

    Absinthe.Plug.put_options(conn, context: context)
  end
end
