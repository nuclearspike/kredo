# 09 — Lender Discovery, Teams, and Messages

## Lender discovery anchor

A lender can tell the system what they want to accomplish and receive localized, explainable, safe recommendations.

Example prompts:

- “I want to support women-owned businesses in Guatemala.”
- “Show me loans that are almost funded.”
- “I care about climate resilience and agriculture.”
- “Find a borrower who has repaid before and is applying again.”
- “Show me loans my team might like.”

## Recommendation criteria

The assistant can use:

- sector,
- activity,
- country/region,
- borrower gender if present and safe,
- themes,
- funding percent,
- days left,
- partner/trust model,
- repayment term,
- prior borrower history,
- team interests,
- lender stated goals,
- language availability.

It must explain why results were chosen.

## Lending teams

### Anchor outcome

A lender can create a lending team through conversation. The system drafts the profile page, suggests a picture URL, sets source language, and creates translation rows.

### Chat flow

```text
Lender: I want to create my own lending team.
Assistant: What kind of group is it — coworkers, family, neighbors, online group, school, faith/community group, or something else?
Lender: Coworkers at our coffee shop.
Assistant: What should the vibe be — serious impact, friendly competition, local community, monthly challenge?
Lender: Friendly competition.
Assistant: Drafts team page: name, tagline, description, image suggestion, first message-board post.
Lender: Use German too.
Assistant: Creates de translation rows and marks English as source unless lender changes source language.
```

### Image URL behavior

For demo, do not actually scrape arbitrary sites unless safe external fetching is intentionally implemented. Use one of:

- mocked image suggestion provider,
- user-provided image URL,
- curated demo image catalog,
- generated placeholder path.

If the user says the group exists online, the assistant can ask for the URL or propose a search/suggestion. It should not silently grab copyrighted images and pretend everything is fine. That dragon has lawyers.

## Message boards

Every team has a message board. Posts are authored in one source language and translated on request.

Tables:

```text
team_posts
team_posts_lc
translation_requests
```

On-demand translation:

1. User views team post in `fr`.
2. `team_posts_lc(fr)` missing.
3. Show fallback and create translation request.
4. Translation job writes `team_posts_lc(fr)`.
5. LiveView updates.

## Encouragement messages to borrowers

### Anchor outcome

Lenders can send kind, moderated, translated encouragement messages that borrowers can read in their native language.

Flow:

```text
lender writes message
  -> moderation check
  -> suggested rewrite if needed
  -> lender confirms final message
  -> source LC row created
  -> translation rows created/requested
  -> borrower sees approved localized message
```

Moderation categories:

- cruelty/insult,
- patronizing savior language,
- romantic/sexual content,
- political/religious pressure,
- solicitation/contact info,
- financial advice beyond scope,
- privacy exposure,
- spam.

## Demo script

Use `lender@kiva.org` / `password`.

Try:

> I want to lend to a borrower in Guatemala who is using the money for textiles or farming and who is almost funded.

Then:

> Write an encouraging message to Rosa and translate it so she can read it in Spanish.

Then:

> Create a lending team for my coworkers at a coffee shop. Make it friendly and competitive.
