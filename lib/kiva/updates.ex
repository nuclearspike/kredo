defmodule Kiva.Updates do
  @moduledoc """
  Field updates a partner posts about a loan's borrower (`kind: "update"`) and
  closing outcomes (`kind: "outcome"`). Posting reveals to every lender of the
  loan (a notification) and is localized on demand — the provider→lender truth
  chain that makes the lending loop feel real.
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver
  alias Kiva.{Translation, Notifications, Audit}
  alias Kiva.Lending.Loan
  alias Kiva.Updates.{BorrowerUpdate, BorrowerUpdateLc}

  @doc "Partner posts an update/outcome on a loan; reveals to its lenders."
  def post_update(author, loan_id, kind, body, source_locale) do
    loan = Repo.get!(Loan, loan_id) |> Repo.preload(:borrower)
    src = source_locale || "en"
    kind = if kind in BorrowerUpdate.kinds(), do: kind, else: "update"

    {:ok, update} =
      %BorrowerUpdate{}
      |> BorrowerUpdate.changeset(%{
        loan_id: loan_id,
        borrower_id: loan.borrower_id,
        author_user_id: uid(author),
        kind: kind,
        source_locale_code: src
      })
      |> Repo.insert()

    %BorrowerUpdateLc{}
    |> BorrowerUpdateLc.changeset(%{
      borrower_update_id: update.id,
      locale_code: src,
      is_source: true,
      source_locale_code: src,
      body: body,
      translation_status: "published"
    })
    |> Repo.insert!()

    {title, ntype} =
      case kind do
        "outcome" -> {"Outcome on a loan you supported 🌱", "loan_outcome"}
        _ -> {"Update on a loan you supported", "borrower_update"}
      end

    Notifications.notify_loan_lenders(
      loan_id,
      ntype,
      title,
      String.slice(body || "", 0, 120),
      "/loans/#{loan.slug}"
    )

    Audit.record(%{
      event_type: "loan.borrower_update",
      actor_user_id: uid(author),
      target_type: "loan",
      target_id: to_string(loan_id),
      summary: "Borrower #{kind} posted on loan ##{loan_id}"
    })

    update
  end

  def list_for_loan(loan_id, locale) do
    BorrowerUpdate
    |> where(loan_id: ^loan_id)
    |> order_by([u], desc: u.inserted_at)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(&localize(&1, locale))
  end

  @doc "On-demand machine translation of an update body (long-tail content)."
  def ensure_translation(update_id, target_locale) do
    update = Repo.get!(BorrowerUpdate, update_id) |> Repo.preload(:translations)
    target = Kiva.Localization.normalize(target_locale)
    source = Enum.find(update.translations, & &1.is_source) || List.first(update.translations)

    cond do
      is_nil(source) ->
        {:error, :no_source}

      existing = Enum.find(update.translations, &(&1.locale_code == target)) ->
        {:ok, existing}

      true ->
        %BorrowerUpdateLc{}
        |> BorrowerUpdateLc.changeset(%{
          borrower_update_id: update.id,
          locale_code: target,
          is_source: false,
          source_locale_code: source.locale_code,
          body: Translation.machine_translate(source.body, source.locale_code, target),
          translated_from_lc_id: source.id,
          translation_status: "machine",
          source_hash: Translation.source_hash(source.body)
        })
        |> Repo.insert()
    end
  end

  defp localize(%BorrowerUpdate{} = u, locale) do
    res = Resolver.resolve_public(u.translations, locale)

    %{
      update: u,
      kind: u.kind,
      body: res.row && res.row.body,
      resolved_locale: res.locale,
      fallback_used: res.fallback_used,
      status: res.row && res.row.translation_status
    }
  end

  defp uid(%{id: id}), do: id
  defp uid(_), do: nil
end
