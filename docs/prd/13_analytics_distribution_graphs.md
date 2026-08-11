# 13 — Analytics and Distribution Graphs

## Demo analytics goal

The demo should visibly communicate that the platform is not just listing loans. It understands global distribution, story flow, trust, translation coverage, team identity, and repayment progress.

## Public/lender graphs

### Loan distribution

- by country,
- by sector,
- by activity,
- by theme,
- by funding percent,
- by time left,
- by trust model,
- by borrower repeat status.

### Portfolio distribution

- lender portfolio by country,
- sector/activity distribution,
- gender if modeled safely,
- trust model mix,
- repayment status,
- team contribution.

### Team profile graphs

- total lent over time,
- sector distribution,
- country distribution,
- active members,
- message activity by language,
- team funding velocity.

## Partner graphs

- active loans by status,
- repayment schedule health,
- borrower repeat rate,
- sector distribution,
- language completeness,
- average review turnaround,
- pre-disbursed vs post-disbursed.

## Admin graphs

- translation debt by locale,
- review queue aging,
- permission outliers,
- moderation block reasons,
- AI chat usage by actor,
- GraphQL denied query attempts,
- funding velocity anomalies,
- partner/trustee risk status,
- borrower portal access by language.

## StoryTime overlay metrics

Attach analytics to actor stages:

- stage entered,
- question asked,
- decision started,
- command previewed,
- command confirmed,
- command abandoned,
- reveal delivered,
- reveal acted on,
- translation requested,
- moderation rejected,
- support escalated,
- outcome confirmed.

## Implementation guidance

For demo v1, seed synthetic analytics snapshots rather than building full event ingestion first. Then instrument real events as implementation proceeds.

Tables:

```text
analytics_events
analytics_daily_rollups
profile_distribution_snapshots
permission_outlier_snapshots
translation_coverage_snapshots
team_distribution_snapshots
partner_distribution_snapshots
```

## Chart examples

- Stacked bar: funding by sector and language availability.
- Map: loans by country.
- Radar/spider: team impact mix.
- Line chart: team cumulative lending.
- Heatmap: translation debt by entity type and locale.
- Sankey-style mock: borrower -> partner -> loan -> lender team -> repayment.
- Scatter: funding velocity vs story completeness score.
