# 04 — AI Chat-First Architecture

## Core idea

Every page has a floating chat widget. The chat is page-aware, role-aware, locale-aware, and command-safe.

It can:

- answer questions,
- explain how the system works,
- query role-scoped GraphQL,
- help users navigate,
- draft structured content,
- propose action cards,
- collect missing information,
- generate a review form,
- trigger registered commands after confirmation.

It cannot:

- mutate state directly,
- bypass permissions,
- query admin data from public/lender/partner/borrower schemas,
- expose hidden truth,
- treat weak inference as fact,
- approve its own translations/moderation for sensitive content,
- perform real financial operations.

## AI actor variants

### Public/lender assistant

Purpose:

- Explain how lending works.
- Help find loans.
- Compare impact goals.
- Create teams.
- Draft encouragement messages.
- Explain risk and repayment.
- Navigate pages.

Allowed schemas:

- PublicGraphQL
- LenderGraphQL after login
- Command preview endpoint for lender-safe commands

### Borrower assistant

Purpose:

- Explain borrower’s own loan status.
- Translate lender messages.
- Explain repayment schedule.
- Help request support or partner contact.
- Explain what public lenders can see.

Allowed schemas:

- BorrowerGraphQL only
- BorrowerCommand preview/confirm for safe borrower actions

### Partner assistant

Purpose:

- Create loan applications conversationally.
- Pull existing borrower data.
- Reuse prior business/sector/activity details.
- Collect story, photo, terms, use of funds.
- Generate review form.
- Submit to staff review.

Allowed schemas:

- PartnerGraphQL
- PartnerCommand preview/confirm

### Staff/admin assistant

Purpose:

- Inspect review queues.
- Query admin-only data.
- Explain permission outliers.
- Summarize risk/trust.
- Review translation/moderation queues.
- Manage partners/trustees.
- Generate operational reports.

Allowed schemas:

- StaffGraphQL
- AdminGraphQL for admin role only
- AdminCommand preview/confirm

## Page-aware context

Every chat session receives a minimal page context object:

```yaml
page_context:
  route: /loans/rosa-weaving-2
  actor_role: lender
  user_id: demo_lender
  locale: de
  focused_object:
    type: loan
    id: loan_rosa_002
  visible_truths:
    - localized title
    - amount
    - funding progress
    - sector/activity
    - partner/trust model
  available_commands:
    - add_to_basket
    - write_encouragement_message
    - compare_similar_loans
  blocked_commands:
    - edit_loan: "Only partner/staff can edit loan."
  hidden_truths:
    - borrower_private_notes
    - admin_risk_internal
```

The page context is not enough to authorize actions. It only narrows interpretation. Permissions still live server-side.

## Ask Mode

Ask Mode answers questions and never mutates state.

Examples:

- “How does repayment work?”
- “Why is this loan pre-disbursed?”
- “Show me women-owned businesses in Guatemala.”
- “What does this borrower need the loan for?”
- “What has my team funded this month?”
- “When is my next repayment due?”

Ask Mode uses:

- role-scoped GraphQL,
- content/wiki retrieval,
- current page context,
- locale preference,
- citations/provenance where useful,
- confidence labeling when data is missing.

## Command Mode

Command Mode proposes and executes registered commands.

Flow:

```text
actor text
  -> intent classification
  -> target resolution
  -> command registry lookup
  -> permission check
  -> state/policy eligibility
  -> missing truth collection
  -> preview card
  -> explicit confirmation if required
  -> deterministic command handler
  -> events/notifications/audit
  -> localized success/failure response
```

Example:

```text
Lender: I want to create a team for my coworkers.
Assistant: Great. What should the team be called?
Lender: The Coffee Fund.
Assistant: Is this for coworkers, friends, family, or an online community?
Lender: Coworkers.
Assistant: Drafts team profile, chooses image suggestion, previews page.
Lender: Looks good.
Assistant: Shows command preview.
Lender: Confirm.
System: create_lending_team command executes.
```

## Generated cards

The AI can request display of approved card schemas:

- Loan comparison card
- Loan recommendation carousel
- Team draft card
- Loan application review card
- Borrower status card
- Repayment schedule card
- Translation review card
- Permission outlier card
- Risk/trust explanation card
- Message moderation suggestion card

Generated UI must use approved schemas. No arbitrary HTML/JS from the model.

## Conversation memory

Store:

- chat session id,
- actor role,
- locale,
- page context snapshot,
- user messages,
- assistant replies,
- GraphQL calls,
- command previews,
- confirmations,
- executed command ids,
- moderation/translation decisions,
- support-relevant summaries.

Do not store irrelevant personal chatter permanently. For demo, keep everything visible to admin for inspection unless hidden by role-specific safety test.

## System prompt architecture

Each bot has:

1. Global product/system prompt.
2. Actor-specific prompt.
3. Locale/style instruction.
4. Page context.
5. Tool/schema declaration.
6. Command registry subset.
7. Forbidden data policy.
8. Response format contract.

Prompts live in `prompts/chatbot_system_prompt_templates.md`.

## Moderation flow for lender messages

```text
lender writes message
  -> AI moderation checks tone, safety, privacy, patronizing language, religious/political weirdness, romantic content, solicitation
  -> if safe: translate into borrower preferred language
  -> if questionable: suggest rewrite
  -> if unsafe: block and explain gently
  -> approved message appears to borrower
```

Do not let the AI silently rewrite a lender’s message and send it as if it were original. Show the suggested rewrite and ask confirmation.

## Language behavior

The assistant should speak the selected UI language by default. Users may override: “answer in Spanish.”

If content is missing in selected language:

1. Use approved fallback.
2. Mark fallback internally.
3. Offer translation if appropriate.
4. Queue translation request for long-tail content.

## Security posture

The LLM never receives raw admin schema unless actor/session authorizes it. Even then, the GraphQL layer must enforce field permissions. The model cannot be the boundary; it is a talkative guest in the boundary’s house.
