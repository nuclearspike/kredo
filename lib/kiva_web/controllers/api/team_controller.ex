defmodule KivaWeb.Api.TeamController do
  @moduledoc "Public localized lending teams."
  use KivaWeb, :controller

  alias Kiva.Teams
  alias KivaWeb.Api.Serializer

  action_fallback KivaWeb.Api.FallbackController

  def index(conn, params) do
    data = Teams.list_localized_teams(locale(params)) |> Enum.map(&Serializer.team_card/1)
    json(conn, %{data: data})
  end

  def show(conn, %{"slug" => slug} = params) do
    case Teams.get_localized_team(slug, locale(params)) do
      nil -> {:error, :not_found}
      team -> json(conn, %{data: Serializer.team_detail(team)})
    end
  end

  defp locale(params), do: Kiva.Localization.normalize(params["locale"])
end
