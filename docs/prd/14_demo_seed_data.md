# 14 — Demo Seed Data

## Required accounts

```yaml
users:
  - email: borrower@kiva.org
    password: password
    role: borrower
    locale: es
    display_name: Rosa Alvarez
  - email: lender@kiva.org
    password: password
    role: lender
    locale: en
    display_name: Morgan Lee
  - email: partner@kiva.org
    password: password
    role: partner
    locale: es
    display_name: Ana Morales
    partner: Community Loom Cooperative
  - email: admin@kiva.org
    password: password
    role: admin
    locale: en
    display_name: Jordan Staff
```

## Fake partners

```yaml
partners:
  - name: Community Loom Cooperative
    country: Guatemala
    trust_model: partner_facilitated
    story: Supports artisan weavers and small rural textile businesses.
  - name: Green Fields Microfinance
    country: Kenya
    trust_model: partner_facilitated
    story: Supports smallholder farmers and climate resilience.
  - name: Austin Community Trust Hub
    country: United States
    trust_model: trustee_backed
    story: Supports underestimated local entrepreneurs through social underwriting.
```

## Fake borrowers

```yaml
borrowers:
  - name: Rosa Alvarez
    country: Guatemala
    preferred_locale: es
    business: Rosa's Weaving Studio
    sector: Arts
    activity: Textiles
    repeat_borrower: true
  - name: Amina Okello
    country: Kenya
    preferred_locale: en
    business: Amina's Seed Cooperative
    sector: Agriculture
    activity: Farming
  - name: Sofia Martinez
    country: United States
    preferred_locale: es
    business: Sofia's Bakery Cart
    sector: Food
    activity: Bakery
```

## Fake loans

```yaml
loans:
  - slug: rosa-weaving-second-loan
    borrower: Rosa Alvarez
    partner: Community Loom Cooperative
    amount_usd: 950
    funded_usd: 720
    trust_model: partner_facilitated
    disbursal_status: pre_disbursed
    sector: Arts
    activity: Textiles
    source_locale: es
    use: Buy cotton thread and natural dyes for a larger weaving order.
    repayment_term_months: 8
  - slug: amina-climate-seeds
    borrower: Amina Okello
    partner: Green Fields Microfinance
    amount_usd: 1200
    funded_usd: 1180
    trust_model: partner_facilitated
    disbursal_status: pre_disbursed
    sector: Agriculture
    activity: Farming
    source_locale: en
    use: Purchase drought-resistant seeds and irrigation supplies.
    repayment_term_months: 10
  - slug: sofia-bakery-cart
    borrower: Sofia Martinez
    partner: Austin Community Trust Hub
    amount_usd: 3000
    funded_usd: 600
    trust_model: trustee_backed
    disbursal_status: direct_disbursal_pending
    sector: Food
    activity: Bakery
    source_locale: es
    use: Purchase a mobile bakery cart and permits.
    repayment_term_months: 18
```

## Fake lending teams

```yaml
teams:
  - name: The Coffee Fund
    source_locale: en
    image_url: /images/demo/coffee-team.jpg
    tagline: Coworkers turning coffee money into working capital.
  - name: Tejedoras Unidas Supporters
    source_locale: es
    image_url: /images/demo/weaving-team.jpg
    tagline: Apoyando a mujeres artesanas y pequeñas empresas textiles.
  - name: Climate Resilience Circle
    source_locale: en
    image_url: /images/demo/climate-team.jpg
    tagline: Loans for farmers adapting to a changing planet.
```

## Fake encouragement messages

```yaml
messages:
  - loan: rosa-weaving-second-loan
    lender: Morgan Lee
    source_locale: en
    body: Your weaving work is beautiful. I hope this loan helps you fill the new order and grow with confidence.
    moderation_status: approved
    borrower_locale_translation: es
  - loan: amina-climate-seeds
    lender: Morgan Lee
    source_locale: en
    body: Wishing you a strong planting season and steady rains.
    moderation_status: approved
```

## Fake translation coverage

Seed all major content with `en`, `es`, `de`, `fr`, `nl` rows where reasonable. Some team posts should intentionally miss `de` or `nl` so on-demand translation can be demonstrated.

## Fake analytics snapshots

Seed:

- loans by country,
- funding by sector,
- translation coverage by locale,
- team lending distribution,
- permission outlier examples,
- AI chat usage by actor.
