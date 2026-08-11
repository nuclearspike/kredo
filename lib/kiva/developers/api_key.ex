defmodule Kiva.Developers.ApiKey do
  @moduledoc """
  An API key for the bespoke Platform API. The raw key (`kva_live_<key_id>_<secret>`)
  is shown once; only its SHA-256 `token_hash` is stored. `key_id` is the indexed
  lookup handle; `prefix`/`last4` are display-only.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "developer_api_keys" do
    field :key_id, :string
    field :prefix, :string
    field :last4, :string
    field :token_hash, :string, redact: true
    field :name, :string
    field :scopes, {:array, :string}, default: []
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime

    belongs_to :app, Kiva.Developers.App, foreign_key: :developer_app_id

    timestamps(type: :utc_datetime)
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, [
      :developer_app_id,
      :key_id,
      :prefix,
      :last4,
      :token_hash,
      :name,
      :scopes,
      :expires_at
    ])
    |> validate_required([:developer_app_id, :key_id, :prefix, :last4, :token_hash])
    |> unique_constraint(:key_id)
    |> unique_constraint(:token_hash)
  end

  def revoked?(%__MODULE__{revoked_at: nil}), do: false
  def revoked?(%__MODULE__{}), do: true
end
