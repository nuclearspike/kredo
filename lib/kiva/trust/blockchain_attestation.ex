defmodule Kiva.Trust.BlockchainAttestation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blockchain_attestations" do
    field :attestation_type, :string, default: "loan_integrity"
    field :proof_hash, :string
    field :chain, :string, default: "mock-attest-v0"
    field :verified, :boolean, default: true
    field :attested_at, :utc_datetime
    belongs_to :loan, Kiva.Lending.Loan
    timestamps(type: :utc_datetime)
  end

  def changeset(a, attrs) do
    a
    |> cast(attrs, [:loan_id, :attestation_type, :proof_hash, :chain, :verified, :attested_at])
    |> validate_required([:loan_id, :proof_hash])
  end
end
