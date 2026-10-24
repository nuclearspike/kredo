# Kredo source-release record

Prepared October 23, 2026 (America/Denver). Owner: Paul Ericksen.

## Intended release

Paul authorized public source publication and the Freelancer portfolio entry
on October 23, 2026. This release presents an engineering prototype with a short
demo and case study. The source and history become public; the local Phoenix
service remains bound to localhost. No hosted lending service is part of this
release. The existing noncommercial license and additional grant are unchanged.

Primary reader: a prospective client or developer. Desired outcome: understand
what Paul directed, see working examples and inspect supporting evidence in
at most three steps: overview → demo → source/verification. When local setup
fails or source access is unavailable, the screenshots and case study remain
a complete read-only introduction.

## Verified preparation

- Baseline: `36cbb482ae6ffa3bc6f27c4821bd782d94d7660c` on `main`, clean before
  this preparation. No application behavior changed in this documentation pass.
- `mix precommit`: warnings-as-errors compile, dependency/format checks and
  **320 tests, zero failures**. Test data used a separate test database.
- Local server started on `127.0.0.1:4100`. Home page rendered, and the assistant
  launcher opened with an explicit offline/scripted status. No hosted model was
  called for this check. Loan discovery opened a selected loan in its detail
  panel and full page. The public borrower account signed in to its Dutch portal;
  the observed locale route rendered the German home and borrower portal.
  These are bounded smoke checks, not full cross-role journey certification.
- Gitleaks 8.30.1 scanned **all 41 reachable commits**, approximately 818 MB of
  history. Seven findings were reviewed: four occurrences of the two fixed
  development/test cookie-signing defaults, and three occurrences of the literal
  documentation placeholder `kva_live_YOUR_KEY`. The historical defaults match
  the current dev/test defaults. Production requires `SECRET_KEY_BASE` from the
  environment. No live service credential was identified by this scan; this is
  a bounded automated scan plus finding review, not proof of absence.
- A separate scan of the 615-file release snapshot found only the two current
  dev/test defaults and the same documentation placeholder. No findings were
  silently suppressed. Raw scan reports are retained outside the public repo.
- 612 tracked baseline files. No tracked local machine paths were found in the
  reviewed text-file types. Generated bulk CSVs, dependencies and build output
  are ignored. No private session transcripts are included.
- Existing screenshots and demo-content generator document synthetic stories,
  people and AI-generated portraits. The public gallery is dated August 12.
- The existing PolyForm Noncommercial license, copyright notice and additional
  grant to Kiva Microfunds are preserved. This preparation does not change rights.

## Known limits

- Financial activity is simulated. There is no real payment processing,
  production ledger or financial reconciliation.
- Demo passwords are public; authentication, OAuth and abuse controls are not
  ready for a public production service. Do not expose the development server.
- Translation, moderation and attestations remain demo implementations. The
  assistant's optional model backend has not been certified by this check.
- August actor audits and scale measurements are historical. A passing suite or
  a screenshot does not close all their findings or establish a production SLA.
- The legacy FractalFlow corpus already reports 11 duplicate-node diagnostics.
  The release docs do not claim a clean structural check; broader contract
  reconciliation remains separate from this portfolio preparation.

## Before changing visibility

Review the final documentation diff and screenshot/PDF demo. Re-run the
secret scan if source or history changes. Commit and push only the reviewed
release files, obtain the owner's release approval, then switch repository
visibility and verify the README, demo images and source links while signed
out. Publish the prepared Freelancer case study only after those links work.
A separate decision and hardening effort is needed for any Internet-hosted app.
