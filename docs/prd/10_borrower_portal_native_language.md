# 10 — Borrower Portal and Native-Language Access

## Anchor outcome

A borrower can log in from a simple device or internet cafe, understand their loan status in their native language, read encouragement from lenders, understand repayment expectations, and know who to contact.

## Borrower portal home

Visible cards:

- greeting,
- active loan summary,
- funding progress,
- repayment schedule,
- next repayment due,
- recent lender messages,
- partner contact,
- ask Kiva chat.

## Borrower questions

The borrower assistant should answer:

- “How much has been funded?”
- “When is my next repayment?”
- “What happens after my loan is funded?”
- “Who are the lenders?”
- “What messages did people send me?”
- “Can I apply for another loan?”
- “Why does the public page say my loan was pre-disbursed?”

## Visibility rules

Borrower can see:

- own borrower profile,
- own loans,
- own repayment schedule,
- approved lender messages,
- partner public notes,
- staff public-facing status.

Borrower cannot see:

- staff risk notes,
- lender private data,
- permission structures,
- internal translation/moderation debate,
- unrelated partner data.

## Device posture

Design for:

- low bandwidth,
- small Android screen,
- shared/public computer,
- short sessions,
- clear logout,
- minimal heavy media,
- printable/large-text schedule view.

## Language behavior

Borrower default locale comes from borrower profile. The globe dropdown remains available.

If message translation is missing, show:

- fallback language if allowed,
- “translation pending” state,
- request translation button if not already queued.

## Encouragement message display

Message card should show:

- lender display name or safe alias,
- localized message,
- original language indicator,
- translated-by-AI/human status if appropriate,
- report issue button.

## Repeat loan prompt

If borrower has completed or is near completion:

```text
Would you like to talk with your partner about another loan?
```

This should not directly create a loan. It routes a borrower interest signal to partner only if borrower confirms. Weak browsing/curiosity stays silent.

## Demo script

Use `borrower@kiva.org` / `password`.

Set language to Spanish. Ask:

> ¿Cuándo es mi próximo pago?

Expected:

- Spanish answer,
- repayment schedule card,
- next payment highlighted,
- source data from BorrowerGraphQL only.
