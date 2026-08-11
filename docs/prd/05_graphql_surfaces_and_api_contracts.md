# 05 — GraphQL Surfaces and API Contracts

## Design principle

GraphQL is the AI-readable and UI-readable product surface. Each actor gets a different schema surface. Do not expose one giant schema and trust the assistant to behave. That is not security. That is a haunted piñata.

## Schema surfaces

### PublicGraphQL

For visitors and unauthenticated public browse.

Can query:

- localized loan cards,
- localized public loan profiles,
- sectors/activities/themes/tags,
- partner public profiles,
- team public profiles,
- FAQ/wiki/video content,
- global stats,
- language metadata.

Cannot query:

- borrower private portal data,
- lender personal data,
- admin review notes,
- partner operational notes,
- permission data,
- moderation details.

### LenderGraphQL

For authenticated lenders.

Can query:

- everything in PublicGraphQL,
- own lender profile,
- own portfolio,
- own lending teams,
- saved searches,
- basket/fake checkout,
- own encouragement messages,
- team message boards by membership/visibility.

Can command through registry:

- update lender profile,
- save search,
- create lending team,
- edit owned team,
- join/leave team,
- add fake loan to basket,
- complete demo lend,
- draft encouragement message,
- submit encouragement message for moderation.

### BorrowerGraphQL

For authenticated borrowers.

Can query:

- own borrower profile,
- own loans,
- own loan statuses,
- funding progress,
- repayment schedules,
- repayments posted,
- approved lender encouragement messages,
- partner/staff public-facing updates,
- FAQ/help content.

Cannot query:

- lender private profile details,
- admin risk notes,
- partner internal notes,
- moderation internals except user-facing explanation.

### PartnerGraphQL

For authenticated partners.

Can query:

- partner profile,
- partner borrowers,
- partner borrower groups,
- partner loans,
- draft loan applications,
- loan review status,
- repayment schedules for partner loans,
- translation status for partner-authored content,
- public lender encouragement summaries for borrowers they serve.

Can command:

- create/update borrower,
- create/update borrower group,
- start repeat loan from existing borrower,
- draft loan application via chat,
- upload mocked photo URL,
- submit loan for staff review,
- propose repayment schedule,
- post borrower update.

### StaffGraphQL

For staff roles.

Can query:

- review queues,
- translation queues,
- moderation queues,
- loan application details,
- partner operational summaries,
- borrower public/private split according to permissions,
- trust checks,
- audit timeline,
- permission outliers.

Can command:

- approve/reject loan content,
- request changes,
- approve/reject translation,
- approve/reject message moderation,
- mark partner/trustee status,
- trigger translation rebuild,
- add staff review note,
- assign review task.

### AdminGraphQL

For true admin only. Separate schema surface.

Can query:

- permission graph,
- role assignments,
- schema access logs,
- AI tool-call logs,
- audit events,
- all review queues,
- system analytics,
- seed/demo configuration.

Can command:

- manage permissions,
- manage supported locales,
- manage staff roles,
- disable AI command categories,
- inspect or revoke suspicious access,
- reset demo seed state.

## AI use of GraphQL

The AI assistant must use GraphQL for data retrieval. It may not query the database directly.

Every AI GraphQL call logs:

```yaml
ai_graphql_query:
  conversation_id:
  actor_role:
  schema_surface:
  operation_name:
  variables:
  fields_requested:
  allowed: true|false
  denial_reason:
  response_shape_hash:
  created_at:
```

## Example operations

### Public: localized loan discovery

```graphql
query PublicLoanSearch($locale: Locale!, $filter: LoanSearchFilter!) {
  loans(locale: $locale, filter: $filter) {
    id
    slug
    title
    shortDescription
    amount
    fundedPercent
    country { code name }
    sector { id name }
    activity { id name }
    trustSummary
    imageUrl
  }
}
```

### Borrower: own loan status

```graphql
query BorrowerLoanStatus($locale: Locale!) {
  myBorrowerPortal(locale: $locale) {
    borrowerName
    loans {
      id
      title
      statusLabel
      fundingProgress
      repaymentSchedule { dueDate amount statusLabel }
      encouragementMessages { fromDisplayName localizedBody }
    }
  }
}
```

### Partner: repeat loan candidate

```graphql
query PartnerBorrowerRepeatLoan($borrowerId: ID!, $locale: Locale!) {
  partnerBorrower(id: $borrowerId, locale: $locale) {
    id
    displayName
    businesses { id name sector activity }
    priorLoans {
      id
      title
      loanUse
      sector { id name }
      activity { id name }
      repaymentSummary
      status
    }
    reuseSuggestions {
      suggestedSectorId
      suggestedActivityId
      suggestedLoanUse
      confidence
      reason
    }
  }
}
```

### Admin: permission outliers

```graphql
query PermissionOutliers {
  permissionOutliers {
    user { id email roleLabels }
    outlierType
    permissionKey
    reason
    severity
    recommendedAction
  }
}
```

## Contract rule

Every GraphQL field should declare:

- actor roles allowed,
- source table/read model,
- localization behavior,
- fallback behavior,
- redaction behavior,
- audit requirement,
- whether AI may query it.

Put the first pass in `schemas/graphql_surface_map.yaml`.
