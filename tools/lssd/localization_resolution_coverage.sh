#!/bin/sh
# Coverage verifier for pattern.localization.sidecar_public_resolution
# (docs/fractalflow/localization_subsystem.lssd.md).
#
# Enumerates candidate modules that touch *_lc translations and checks each is
# either resolver-conforming (calls Resolver.resolve_public) or deliberately
# allowlisted. New rendering paths that bypass the resolver fail this script,
# which is exactly the drift the pattern exists to catch.
set -eu
cd "$(dirname "$0")/../.."

# Modules allowed to READ LC rows without resolve_public, with reasons:
#   lib/kiva/localization/resolver.ex  - the pattern's own implementation
#   lib/kiva/translation.ex            - lifecycle writer; staff review reads raw rows by design
#                                        (policy translation_review_staff_only)
#   lib/kiva/localization.ex           - locale truths/formatting; no entity-text rendering
#   lib/kiva/commands/eligibility.ex   - required_lc_source_exists gate checks row presence only
#   lib/kiva/loan_applications.ex      - partner authoring reads/writes the SOURCE row, never a
#                                        localized public render
#   lib/kiva_web/live/admin_live.ex    - staff review detail lists raw per-locale coverage by design
#   lib/kiva/provenance/fabricator.ex  - demo fabricator reads raw LC rows to generate provenance
#                                        ABOUT translations (all statuses incl. rejected); it renders
#                                        nothing public
#   lib/kiva_web/controllers/kiva_v1/* and lib/kiva_web/kiva_graphql/* resolve via
#     Kiva.KivaCompat.Mapping to mirror legacy Kiva language semantics (languages
#     arrays / lang params); the product badge+fallback contract does not apply
#     to the compat machine surface (see the adoption's exceptions)
ALLOWLIST='lib/kiva/localization/resolver.ex
lib/kiva/translation.ex
lib/kiva/localization.ex
lib/kiva/commands/eligibility.ex
lib/kiva/loan_applications.ex
lib/kiva/provenance/fabricator.ex
lib/kiva_web/live/admin_live.ex
lib/kiva_web/controllers/kiva_v1/loan_json.ex
lib/kiva_web/controllers/kiva_v1/partner_json.ex
lib/kiva_web/controllers/kiva_v1/team_json.ex
lib/kiva_web/kiva_graphql/loan_shape.ex
lib/kiva_web/kiva_graphql/resolvers.ex'

# Candidates USE translations (preload/access); a bare has_many declaration in a
# schema module is not a rendering path and is excluded.
candidates=''
for f in $(grep -rl ':translations\|\.translations' lib --include='*.ex' | sort -u); do
  if grep -v 'has_many' "$f" | grep -q ':translations\|\.translations'; then
    candidates="$candidates $f"
  fi
done
conforming=$(grep -rl 'resolve_public' lib --include='*.ex' | sort -u)

status=0
checked=0
for f in $candidates; do
  checked=$((checked + 1))
  case "$conforming" in *"$f"*) continue ;; esac
  case "$ALLOWLIST" in *"$f"*) continue ;; esac
  echo "UNCOVERED: $f uses translations without resolve_public (add resolver use, or allowlist with a reason)"
  status=1
done

[ "$status" -eq 0 ] && echo "localization resolution coverage: OK ($checked candidate file(s) checked)"
exit $status
