defmodule Kiva.TrustTest do
  use Kiva.DataCase, async: true

  import Kiva.LendingFixtures
  alias Kiva.Trust

  test "trust picture is localized, with checks and a mock attestation" do
    loan = loan_fixture().loan

    trustee =
      Trust.upsert_trustee("tr", "US", %{
        "en" => {"Trustee EN", "bio"},
        "es" => {"Fideicomisario ES", "bio es"}
      })

    Trust.add_endorsement(loan.id, trustee.id, loan.borrower_id, "en", %{
      "en" => "Trustworthy",
      "es" => "Confiable"
    })

    Trust.add_check(loan.id, loan.borrower_id, "identity", "passed", "ID ok")
    att = Trust.attest(loan.id, "content")
    assert byte_size(att.proof_hash) == 64

    trust = Trust.get_trust_for_loan(loan.id, "es")
    [e] = trust.endorsements
    assert e.trustee_name == "Fideicomisario ES"
    assert e.statement == "Confiable"
    assert [%{check_type: "identity", status: "passed"}] = trust.checks
    assert trust.attestation.verified
  end

  test "attestation is idempotent per loan/type" do
    loan = loan_fixture().loan
    a1 = Trust.attest(loan.id, "one")
    a2 = Trust.attest(loan.id, "two")
    assert a1.id == a2.id
    refute a1.proof_hash == a2.proof_hash
  end
end
