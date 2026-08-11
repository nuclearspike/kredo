#!/bin/bash
# Bulk-loads the lean historical loans produced by build_1m.py (loans + loans_lc
# only) via psql \copy. Override the target database with KREDO_DB.
set -e
DB="${KREDO_DB:-kiva_dev}"
CSV="$(cd "$(dirname "$0")" && pwd)/csv"
copy() { echo "  loading $2 -> $1..."; t0=$(date +%s); psql "$DB" -q -c "\\copy $1($3) FROM '$CSV/$2' WITH (FORMAT csv)"; echo "    $(($(date +%s)-t0))s"; }
copy loans loans_1m.csv "id,slug,status,partner_id,borrower_id,country_code,sector_id,activity_id,trust_model,loan_amount_cents,funded_amount_cents,currency_code,disbursal_status,disbursed_at,fundraising_started_at,fundraising_ends_at,repayment_term_months,repayment_frequency,source_locale_code,inserted_at,updated_at,changes_requested_reason"
copy loans_lc loans_lc_1m.csv "id,loan_id,title,short_description,borrower_story,loan_use,repayment_summary,risk_summary_public,locale_code,is_source,source_locale_code,translation_status,translated_from_lc_id,version,source_hash,inserted_at,updated_at"
echo "  resetting sequences..."
for t in loans loans_lc; do
  psql "$DB" -qtAc "SELECT setval(pg_get_serial_sequence('$t','id'), (SELECT max(id) FROM $t))" >/dev/null
done
echo "DONE"
