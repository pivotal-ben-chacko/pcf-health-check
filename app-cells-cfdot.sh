#!/usr/bin/env bash
#
# app-cells-cfdot.sh -- identify the Diego cells a list of apps reside on,
#                       using only the bosh CLI + cfdot (no cf CLI).
#
# Usage:  ./app-cells-cfdot.sh <apps-file>
#   apps-file: one app name per line (blank lines and '#' comments ignored).
#              If the same app name exists in several orgs/spaces, every
#              match is included (org/space shown to disambiguate).
#
# Designed to run on the opsman VM (same as pcf-health-check.sh). Read-only.
#
# How it works:
#   1. One 'bosh ssh' to a Diego cell runs three cfdot queries in a login
#      shell (cfdot is only on PATH in login shells):
#        - desired-lrps : TAS stamps each LRP's metric_tags with app_name /
#                         organization_name / space_name (the tags Loggregator
#                         uses), so app names resolve from the BBS itself --
#                         no CF API needed.
#        - cells        : cell_id -> rep IP
#        - actual-lrps  : process_guid + cell_id + state per app instance
#   2. 'bosh vms' maps each rep IP back to the cell's BOSH instance name.
#   3. Output is grouped per cell: each Diego cell is printed exactly once,
#      with every listed app residing on it (and its instance count).
#
# Note: 'cfdot desired-lrps' returns full LRP definitions, so on a foundation
# with thousands of apps the SSH transfer can take a while; it is still a
# single round-trip.

set -euo pipefail

DIEGO_CELL_GROUPS_RE="${DIEGO_CELL_GROUPS_RE:-^(compute|diego_cell|isolated_diego_cell)}"

APPS_FILE="${1:-}"
if [[ -z "$APPS_FILE" || ! -r "$APPS_FILE" ]]; then
  echo "usage: $0 <apps-file>   (one app name per line)" >&2
  exit 2
fi

# Authenticate the bosh CLI the same way the health check does.
[[ -z "${BOSH_ENVIRONMENT:-}" && -r "$HOME/env.sh" ]] && . "$HOME/env.sh" >/dev/null

for c in bosh jq; do
  command -v "$c" >/dev/null || { echo "ERROR: '$c' CLI not found on PATH" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
# 0. Read the requested app names.
# ---------------------------------------------------------------------------
APP_NAMES=()
while IFS= read -r app || [[ -n "$app" ]]; do
  app="${app#"${app%%[![:space:]]*}"}"; app="${app%"${app##*[![:space:]]}"}"
  [[ -z "$app" || "$app" == \#* ]] && continue
  APP_NAMES+=("$app")
done <"$APPS_FILE"
[[ ${#APP_NAMES[@]} -gt 0 ]] || { echo "ERROR: no app names in ${APPS_FILE}." >&2; exit 2; }
names_json="$(printf '%s\n' "${APP_NAMES[@]}" | jq -R . | jq -s 'unique')"

# ---------------------------------------------------------------------------
# 1. Find a Diego cell to SSH to, and build IP -> BOSH instance map.
# ---------------------------------------------------------------------------
echo "Locating a Diego cell and building the cell map from 'bosh vms'..." >&2
declare -A INST_BY_IP
cell_dep="" cell_grp=""
while IFS=$'\t' read -r dep inst ips; do
  for ip in ${ips//,/ }; do INST_BY_IP["$ip"]="$inst"; done
  if [[ -z "$cell_grp" && "${inst%%/*}" =~ $DIEGO_CELL_GROUPS_RE ]]; then
    cell_dep="$dep"; cell_grp="${inst%%/*}"
  fi
done < <(
  bosh deployments --json 2>/dev/null | jq -r '.Tables[0].Rows[].name' \
  | while read -r d; do
      bosh -d "$d" vms --json 2>/dev/null \
        | jq -r --arg d "$d" '.Tables[0].Rows[] | [$d, .instance, .ips] | @tsv'
    done
)
[[ -n "$cell_grp" ]] || { echo "ERROR: no instance group matched /${DIEGO_CELL_GROUPS_RE}/." >&2; exit 2; }

# ---------------------------------------------------------------------------
# 2. One login-shell SSH: desired LRPs + cell registry + actual LRPs.
#    (Same invocation pattern as pcf-health-check.sh section 5.)
# ---------------------------------------------------------------------------
echo "Querying the Diego BBS via ${cell_dep}/${cell_grp}/0 (cfdot)..." >&2
raw="$(timeout 300 bosh -d "$cell_dep" ssh "${cell_grp}/0" \
        -c 'bash -lc "echo @@DL; cfdot desired-lrps; echo @@CELLS; cfdot cells; echo @@LRP; cfdot actual-lrps"' 2>/dev/null \
        | sed -e 's/\r$//' -e 's/^[^|]*stdout | //')"
desired_json="$(awk '/^@@DL$/{f=1;next} /^@@CELLS$/{f=0} f' <<<"$raw" | grep '^{' || true)"
cells_json="$(awk  '/^@@CELLS$/{f=1;next} /^@@LRP$/{f=0} f'  <<<"$raw" | grep '^{' || true)"
lrp_json="$(awk    '/^@@LRP$/{f=1;next} f'                   <<<"$raw" | grep '^{' || true)"
[[ -n "$desired_json" ]] || { echo "ERROR: could not retrieve desired-lrps from the BBS via cfdot." >&2; exit 2; }

# cell_id -> BOSH instance (cfdot cells rep_address carries the cell IP)
declare -A INST_BY_CELL_ID
while IFS=$'\t' read -r cid addr; do
  [[ -z "$cid" ]] && continue
  ip="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$addr" | head -1 || true)"
  INST_BY_CELL_ID["$cid"]="${INST_BY_IP[$ip]:-unknown (rep ${addr})}"
done < <(jq -r '[.cell_id, (.rep_address // .rep_url // "")] | @tsv' <<<"$cells_json")

# ---------------------------------------------------------------------------
# 3. Match requested names against desired-LRP metric tags.
#    process_guid -> "app (org/space)"
# ---------------------------------------------------------------------------
declare -A PG_LABEL FOUND_NAME
while IFS=$'\t' read -r pg an org space; do
  [[ -z "$pg" ]] && continue
  PG_LABEL["$pg"]="${an} (${org}/${space})"
  FOUND_NAME["$an"]=1
done < <(jq -r --argjson N "$names_json" '
    (.metric_tags.app_name.static       // .metric_tags.app_name       // "") as $an
  | select($an != "" and ($N | index($an)))
  | [.process_guid, $an,
     (.metric_tags.organization_name.static // .metric_tags.organization_name // "?"),
     (.metric_tags.space_name.static        // .metric_tags.space_name        // "?")]
  | @tsv' <<<"$desired_json")

missing=0
for n in "${APP_NAMES[@]}"; do
  if [[ -z "${FOUND_NAME[$n]:-}" ]]; then
    echo "WARN: app '$n' has no desired LRP in the BBS (not found, stopped, or has no instances)" >&2
    missing=$((missing + 1))
  fi
done
[[ ${#PG_LABEL[@]} -gt 0 ]] || { echo "ERROR: none of the listed apps were found in the BBS." >&2; exit 2; }

# ---------------------------------------------------------------------------
# 4. Walk the actual LRPs and group instances by Diego cell.
# ---------------------------------------------------------------------------
SEP=$'\x1f'
declare -A CELL_TOTAL APPCELL CID_BY_CELL
unplaced=""
instances=0
while IFS=$'\t' read -r pg idx state cid; do
  [[ -z "$pg" ]] && continue
  label="${PG_LABEL[$pg]:-}"
  [[ -z "$label" ]] && continue
  instances=$((instances + 1))
  if [[ -z "$cid" || "$cid" == "-" ]]; then
    unplaced+="  ${label} #${idx}: ${state} (no cell)"$'\n'
    continue
  fi
  cell="${INST_BY_CELL_ID[$cid]:-unknown}"
  CID_BY_CELL["$cell"]="$cid"
  CELL_TOTAL["$cell"]=$(( ${CELL_TOTAL[$cell]:-0} + 1 ))
  APPCELL["${cell}${SEP}${label}"]=$(( ${APPCELL["${cell}${SEP}${label}"]:-0} + 1 ))
done < <(jq -r '[.process_guid, (.index|tostring), .state,
                 (.cell_id // "" | if . == "" then "-" else . end)] | @tsv' <<<"$lrp_json")

# ---------------------------------------------------------------------------
# 5. Report: one row per distinct Diego cell.
# ---------------------------------------------------------------------------
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf 'DIEGO_CELL\tCELL_ID\tINSTANCES\tAPPS\n' >"$tmp"
while IFS= read -r cell; do
  [[ -z "$cell" ]] && continue
  apps=""
  while IFS= read -r k; do
    label="${k#*"$SEP"}"
    apps+="${apps:+, }${label} x${APPCELL[$k]}"
  done < <(printf '%s\n' "${!APPCELL[@]}" | grep -F "${cell}${SEP}" | sort)
  printf '%s\t%s\t%s\t%s\n' "$cell" "${CID_BY_CELL[$cell]}" "${CELL_TOTAL[$cell]}" "$apps" >>"$tmp"
done < <(printf '%s\n' "${!CELL_TOTAL[@]}" | sort)

echo
column -t -s $'\t' "$tmp"
echo
echo "Summary: ${instances} instance(s) of ${#PG_LABEL[@]} matched app(s) across ${#CELL_TOTAL[@]} distinct Diego cell(s)."
if [[ -n "$unplaced" ]]; then
  echo "Instances not currently placed on any cell:"
  printf '%s' "$unplaced"
fi
[[ $missing -gt 0 ]] && { echo "WARN: ${missing} app(s) from the list were not found." >&2; exit 1; }
exit 0
