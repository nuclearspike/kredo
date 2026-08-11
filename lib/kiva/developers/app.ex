defmodule Kiva.Developers.App do
  @moduledoc """
  A developer application. Its `app_id` is the public client identifier and also
  serves as the OAuth2 `client_id`; `client_secret_hash` is the SHA-256 of a
  secret shown to the developer exactly once. Apps own `api_keys` for the
  bespoke Platform API.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :app_id}
  schema "developer_apps" do
    field :owner_user_id, :integer
    field :app_id, :string
    field :client_secret_hash, :string, redact: true
    field :name, :string
    field :description, :string
    field :website, :string
    field :redirect_uris, {:array, :string}, default: []
    field :status, :string, default: "active"

    has_many :api_keys, Kiva.Developers.ApiKey, foreign_key: :developer_app_id

    timestamps(type: :utc_datetime)
  end

  @doc "User-editable fields. Secret/app_id/owner are set by the context, never cast."
  def changeset(app, attrs) do
    app
    |> cast(attrs, [:name, :description, :website, :redirect_uris])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> update_change(:redirect_uris, &clean_uris/1)
    |> validate_redirect_uris()
    |> unique_constraint(:app_id)
  end

  defp clean_uris(nil), do: []

  defp clean_uris(uris) when is_list(uris),
    do: uris |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp validate_redirect_uris(changeset) do
    validate_change(changeset, :redirect_uris, fn :redirect_uris, uris ->
      if Enum.all?(uris, &valid_uri?/1),
        do: [],
        else: [redirect_uris: "must be absolute http(s) URLs"]
    end)
  end

  defp valid_uri?(uri) do
    case URI.parse(uri) do
      %URI{scheme: s, host: h} when s in ["http", "https"] and is_binary(h) and h != "" -> true
      _ -> false
    end
  end
end
