defmodule KivaWeb.Schema.Middleware.Authorize do
  @moduledoc "Field-level role gate. The model is never the boundary; this is."
  @behaviour Absinthe.Middleware

  def call(resolution, allowed_roles) do
    role = resolution.context[:actor_role] || "public"

    if role in allowed_roles do
      resolution
    else
      Absinthe.Resolution.put_result(
        resolution,
        {:error, "unauthorized: requires #{Enum.join(allowed_roles, " or ")}"}
      )
    end
  end
end
