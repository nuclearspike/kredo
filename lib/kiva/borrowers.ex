defmodule Kiva.Borrowers do
  @moduledoc """
  Borrower context: partner-driven onboarding (create a borrower + its source
  language-content row, with an optional photo) and reads for the
  native-language portal.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.Borrowers.{Borrower, BorrowerLc}

  def get_by_user(user_id) do
    Repo.one(from b in Borrower, where: b.user_id == ^user_id, preload: [:translations])
  end

  def display_name(%Borrower{} = b, locale) do
    case Resolver.resolve_public(b.translations, locale).row do
      nil -> b.public_id
      row -> row.display_name
    end
  end

  @doc """
  Onboard a new borrower for a partner: creates the canonical borrower (with an
  optional `image_url`) plus its source `borrowers_lc` row. `partner_id` is set
  by the caller from the authenticated partner, never from user input.
  """
  def create_borrower(partner_id, attrs) do
    name = attrs["name"] || attrs[:name]
    locale = blank_to(attrs["preferred_locale_code"], "en")

    {:ok, borrower} =
      %Borrower{}
      |> Borrower.changeset(%{
        public_id: unique_public_id(name),
        country_code: attrs["country_code"],
        preferred_locale_code: locale,
        partner_id: partner_id,
        sector_id: to_int(attrs["sector_id"]),
        activity_id: to_int(attrs["activity_id"]),
        image_url: blank_to(attrs["image_url"], nil)
      })
      |> Repo.insert()

    %BorrowerLc{}
    |> BorrowerLc.changeset(%{
      borrower_id: borrower.id,
      locale_code: locale,
      is_source: true,
      source_locale_code: locale,
      display_name: name,
      public_bio: attrs["public_bio"],
      business_summary: attrs["business_summary"],
      translation_status: "published"
    })
    |> Repo.insert!()

    borrower
  end

  defp unique_public_id(name) do
    base =
      (name || "borrower")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

    base = if base == "", do: "borrower", else: base

    if Repo.exists?(from b in Borrower, where: b.public_id == ^base),
      do: "#{base}-#{System.unique_integer([:positive])}",
      else: base
  end

  defp to_int(nil), do: nil
  defp to_int(""), do: nil
  defp to_int(i) when is_integer(i), do: i

  defp to_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, _} -> i
      :error -> nil
    end
  end

  defp blank_to(v, default) when v in [nil, ""], do: default
  defp blank_to(v, _), do: v
end
