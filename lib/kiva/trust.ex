defmodule Kiva.Trust do
  @moduledoc """
  Trust network: trustees, endorsements, alternative checks, and **mock**
  blockchain attestations. Surfaces a transparent, localized trust/risk picture
  per loan. Trust models are configurable on the loan itself (`loan.trust_model`).
  """
  import Ecto.Query, warn: false
  alias Kiva.Repo
  alias Kiva.Localization.Resolver

  alias Kiva.Trust.{
    Trustee,
    TrusteeLc,
    Endorsement,
    EndorsementLc,
    AlternativeCheck,
    BlockchainAttestation
  }

  @doc "Full localized trust picture for a loan."
  def get_trust_for_loan(loan_id, locale) do
    endorsements =
      Endorsement
      |> where(loan_id: ^loan_id)
      |> preload([:translations, trustee: :translations])
      |> Repo.all()
      |> Enum.map(&localize_endorsement(&1, locale))

    checks =
      Repo.all(from c in AlternativeCheck, where: c.loan_id == ^loan_id, order_by: c.check_type)

    attestation =
      Repo.one(from a in BlockchainAttestation, where: a.loan_id == ^loan_id, limit: 1)

    %{endorsements: endorsements, checks: checks, attestation: attestation}
  end

  @doc "All trustees with localized name + status (admin review)."
  def list_trustees(locale) do
    Trustee
    |> order_by(:slug)
    |> preload(:translations)
    |> Repo.all()
    |> Enum.map(fn t ->
      name = (Resolver.resolve_public(t.translations, locale).row || %{name: t.slug}).name
      %{trustee: t, name: name, status: t.status}
    end)
  end

  @doc "Admin: set a trustee's status (active | suspended)."
  def set_trustee_status(id, status) do
    Repo.get!(Trustee, id) |> Trustee.changeset(%{status: status}) |> Repo.update!()
  end

  @doc "Compute and store a mock integrity attestation for a loan's content."
  def attest(loan_id, content) do
    hash = :crypto.hash(:sha256, "loan:#{loan_id}:#{content}") |> Base.encode16(case: :lower)

    %BlockchainAttestation{}
    |> BlockchainAttestation.changeset(%{
      loan_id: loan_id,
      attestation_type: "loan_integrity",
      proof_hash: hash,
      chain: "mock-attest-v0",
      verified: true,
      attested_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!(
      on_conflict: {:replace, [:proof_hash, :verified, :attested_at]},
      conflict_target: [:loan_id, :attestation_type]
    )
  end

  defp localize_endorsement(%Endorsement{} = e, locale) do
    statement = Resolver.resolve_public(e.translations, locale).row

    trustee_name =
      e.trustee &&
        (Resolver.resolve_public(e.trustee.translations, locale).row || %{name: e.trustee.slug}).name

    %{
      endorsement: e,
      trustee_name: trustee_name,
      statement: statement && statement.statement,
      status: e.status
    }
  end

  # --- seeds ---
  def upsert_trustee(slug, country, lc) do
    Repo.insert!(%Trustee{slug: slug, country_code: country, status: "active"},
      on_conflict: {:replace, [:country_code]},
      conflict_target: :slug
    )

    trustee = Repo.get_by!(Trustee, slug: slug)

    for {loc, {name, bio}} <- lc do
      Repo.insert!(
        TrusteeLc.changeset(%TrusteeLc{}, %{
          trustee_id: trustee.id,
          locale_code: loc,
          is_source: loc == "en",
          source_locale_code: "en",
          name: name,
          bio: bio
        }),
        on_conflict: {:replace, [:name, :bio]},
        conflict_target: [:trustee_id, :locale_code, :version]
      )
    end

    trustee
  end

  def add_endorsement(loan_id, trustee_id, borrower_id, source, statements) do
    e =
      Repo.insert!(%Endorsement{
        loan_id: loan_id,
        trustee_id: trustee_id,
        borrower_id: borrower_id,
        status: "endorsed",
        source_locale_code: source
      })

    for {loc, statement} <- statements do
      Repo.insert!(
        EndorsementLc.changeset(%EndorsementLc{}, %{
          trust_endorsement_id: e.id,
          locale_code: loc,
          is_source: loc == source,
          source_locale_code: source,
          statement: statement
        })
      )
    end

    e
  end

  def add_check(loan_id, borrower_id, check_type, status, detail) do
    Repo.insert!(%AlternativeCheck{
      loan_id: loan_id,
      borrower_id: borrower_id,
      check_type: check_type,
      status: status,
      detail: detail
    })
  end
end
