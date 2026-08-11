# 12 — Trust Networks, Blockchain, and Alternative Underwriting

## Philosophy

Trust should be modeled as layered evidence, not as a single score. A loan can be trusted through partner history, borrower repayment history, social underwriting, trustee endorsement, alternative verification, and transparent risk disclosure.

## Trust artifacts

```text
trust_endorsements
alternative_checks
partner_due_diligence_reviews
trustee_profiles
borrower_prior_repayment_summaries
blockchain_attestations
risk_summaries
risk_summaries_lc
```

## Trust model display

Loan profile should show a trust explanation card:

- who facilitated the loan,
- whether funds were pre-disbursed,
- who endorses borrower,
- what checks were performed,
- repayment/risk transparency,
- what lenders should understand.

## Trustee endorsements

Trustee endorsement fields:

- trustee id,
- borrower id,
- loan id,
- source locale,
- endorsement text,
- relationship type,
- confidence basis,
- visibility,
- expiration/review date.

## Social underwriting

Social underwriting support options:

- friends/family early lenders,
- trustee endorsement,
- community partner endorsement,
- coworker/customer references,
- prior platform repayment,
- group guarantee.

## Alternative background checks

Model checks as claims, not absolute truth:

```yaml
alternative_check:
  type: mobile_money_history | business_registration | supplier_reference | marketplace_profile | cooperative_membership | training_completion
  source_actor:
  evidence_url_or_note:
  confidence:
  valid_for:
  not_valid_for:
  reviewed_by:
  expires_at:
```

## Blockchain attestation mock

Use a mock attestation table:

```text
blockchain_attestations
- id
- attestation_type
- subject_type
- subject_id
- chain_name
- transaction_hash
- payload_hash
- issued_by
- issued_at
- verification_status
```

Display as:

> “This partner endorsement has a mock public attestation showing the review record has not changed since listing.”

Never display as:

> “Blockchain proves this borrower will repay.”

No. Bad system. Put down the techno-crystal.

## Trust analytics

Graphs:

- repayment by trust model,
- funding velocity by trust model,
- repeat borrower success,
- partner portfolio risk,
- trustee endorsement outcomes,
- translation coverage by trust model,
- borrower update frequency vs repayment.
