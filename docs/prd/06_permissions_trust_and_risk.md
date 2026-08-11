# 06 — Permissions, Trust, and Risk

## Permission model

Use RBAC for broad role grouping and ABAC for object-specific checks.

Actors:

- public visitor,
- borrower,
- lender,
- partner staff,
- trustee,
- translation volunteer,
- content reviewer,
- moderation reviewer,
- support staff,
- finance staff,
- admin,
- AI agent.

## Tables

```text
roles
permissions
permission_groups
role_permission_groups
user_permission_groups
user_permissions
object_permissions
permission_audit_events
permission_outlier_snapshots
```

## Permission naming

Use stable permission keys:

```text
loan.public.read
loan.private.read
loan.draft.create
loan.draft.update_own_partner
loan.review.approve
loan.review.reject
translation.review.approve
message.moderation.approve
admin.permission.manage
admin.ai_logs.read
borrower.own_loan.read
partner.own_borrowers.read
lender.own_portfolio.read
team.own.manage
```

## Permission groups

Examples:

- `group.public_browse`
- `group.lender_basic`
- `group.borrower_portal`
- `group.partner_loan_application`
- `group.translation_reviewer`
- `group.message_moderator`
- `group.loan_reviewer`
- `group.support_staff`
- `group.finance_staff`
- `group.admin`

## ABAC examples

A partner can update a draft loan only when:

```text
actor.role includes partner
AND loan.partner_id == actor.partner_id
AND loan.status in [draft, changes_requested]
```

A borrower can read a loan only when:

```text
actor.role includes borrower
AND loan_borrowers.borrower_user_id == actor.user_id
```

A lender can read team private board only when:

```text
team.visibility == public OR team_membership.user_id == actor.user_id
```

## Permission outlier analysis

Create dashboard cards:

- users with direct permissions outside role groups,
- partner users with access to multiple partner ids,
- translators with admin-only permissions,
- staff with stale elevated role,
- AI tool calls denied by permissions,
- admin permissions unused for 30+ days,
- user has both borrower and staff role,
- user has access to review content in languages they cannot review.

## Trust models for loans

### Partner-facilitated

A local partner screens, disburses, supports, and collects repayments. Loan can be pre-disbursed.

### Direct

Borrower applies directly. Kiva-like platform handles eligibility and disbursal in demo as mock.

### Trustee-backed

A trustee endorses borrower and vouches for character/business readiness.

### Social-underwritten

Borrower receives support from community endorsements, early backing, or network confidence.

### Alternative-check-backed

Alternative background checks can include:

- business registration evidence,
- sales receipts,
- mobile money history,
- cooperative membership,
- community leader endorsement,
- marketplace sales profile,
- supplier references,
- repayment history with prior partner,
- device/account verification,
- training completion,
- peer group guarantee.

### Blockchain-attested

Mock only for demo.

Use blockchain-style attestations as a transparent record of claims, not as magical proof of truth. A hash can prove a record existed; it does not prove the borrower is real, honest, or financially viable. Blockchain without trust semantics is just a spreadsheet wearing sunglasses.

Attestation examples:

- partner endorsement hash,
- loan terms hash,
- repayment schedule hash,
- identity-verification event hash,
- trustee endorsement hash,
- funding allocation proof.

## Risk transparency

Every loan should have public-facing risk explanations:

- repayment is not guaranteed,
- partner risk if applicable,
- direct-loan risk if applicable,
- currency risk if applicable,
- pre-disbursal explanation if applicable,
- social-underwriting confidence if applicable,
- trustee endorsement if applicable.

Admin sees internal risk detail. Lender sees useful risk truth. Borrower sees supportive, non-stigmatizing status. Partner sees operational tasks.

## AI safety for trust/risk

The assistant can explain risk but must not imply guarantees. It should avoid emotionally coercive fundraising language. It may say “this loan aligns with your stated goals,” not “you should fund this because Rosa needs you.” Tiny difference, enormous moral blast radius.
