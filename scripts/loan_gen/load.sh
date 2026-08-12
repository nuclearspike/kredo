#!/bin/bash
# Bulk-loads the CSVs produced by build_csv.py via psql \copy.
# Override the target database with KREDO_DB (default: kiva_dev).
set -e
DB="${KREDO_DB:-kiva_dev}"
CSV="$(cd "$(dirname "$0")" && pwd)/csv"
copy() { echo "  loading $1..."; t0=$(date +%s); psql "$DB" -q -c "\copy $1($2) FROM '$CSV/$1.csv' WITH (FORMAT csv)"; echo "    $(($(date +%s)-t0))s"; }
copy users "id,email,encrypted_password,display_name,role,default_locale_code,inserted_at,updated_at,managed_partner_id,avatar_url"
copy borrowers "id,user_id,public_id,country_code,preferred_locale_code,partner_id,sector_id,activity_id,image_url,inserted_at,updated_at"
copy borrowers_lc "id,borrower_id,display_name,public_bio,business_summary,locale_code,is_source,source_locale_code,translation_status,translated_from_lc_id,version,source_hash,inserted_at,updated_at"
copy loans "id,slug,status,partner_id,borrower_id,country_code,sector_id,activity_id,trust_model,loan_amount_cents,funded_amount_cents,currency_code,disbursal_status,disbursed_at,fundraising_started_at,fundraising_ends_at,repayment_term_months,repayment_frequency,source_locale_code,inserted_at,updated_at,changes_requested_reason"
copy loans_lc "id,loan_id,title,short_description,borrower_story,loan_use,repayment_summary,risk_summary_public,locale_code,is_source,source_locale_code,translation_status,translated_from_lc_id,version,source_hash,inserted_at,updated_at"
copy repayment_schedules "id,loan_id,schedule_type,starts_on,term_months,frequency,inserted_at,updated_at"
copy repayment_schedule_items "id,repayment_schedule_id,due_on,amount_cents,status,paid_on,inserted_at,updated_at"
copy lendings "id,user_id,loan_id,lending_team_id,amount_cents,inserted_at"
copy borrower_updates "id,loan_id,borrower_id,author_user_id,kind,source_locale_code,inserted_at,updated_at"
copy borrower_updates_lc "id,borrower_update_id,body,locale_code,is_source,source_locale_code,translation_status,translated_from_lc_id,version,source_hash,inserted_at,updated_at"
copy notifications "id,user_id,type,title,body,link,read_at,inserted_at"
copy audit_events "id,actor_user_id,actor_role,event_type,target_type,target_id,summary,metadata,inserted_at"
echo "  recomputing team lifetime totals..."
psql "$DB" -qc "UPDATE lending_teams SET total_lent_cents = COALESCE((SELECT SUM(l.amount_cents) FROM lendings l WHERE l.lending_team_id = lending_teams.id), 0)"
echo "  resetting sequences..."
for t in users borrowers borrowers_lc loans loans_lc repayment_schedules repayment_schedule_items lendings borrower_updates borrower_updates_lc notifications audit_events; do
  psql "$DB" -qtAc "SELECT setval(pg_get_serial_sequence('$t','id'), (SELECT max(id) FROM $t))" >/dev/null
done

# COPY leaves every page unmarked in the visibility map, and Postgres will not
# use an index-only scan on a page it cannot prove is all-visible. Without this,
# the paged API's exact-total count reads the whole 225 MB table instead of an
# 8 MB index -- 62ms rather than 22ms. VACUUM sets the map; ANALYZE gives the
# planner real row counts to choose the plan with. Do not reduce this to ANALYZE:
# statistics alone leave the visibility map cold and the scan on the heap.
echo "  vacuum + analyze (sets the visibility map so counts stay on the index)..."
for t in users borrowers borrowers_lc loans loans_lc repayment_schedules repayment_schedule_items lendings borrower_updates borrower_updates_lc notifications audit_events lending_teams; do
  psql "$DB" -qc "VACUUM (ANALYZE) $t"
done
echo "DONE"
