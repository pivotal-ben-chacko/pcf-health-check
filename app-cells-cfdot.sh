#!/usr/bin/env bash
#
# app-cells-cfdot.sh -- map CF apps to Diego cells using the BBS (cfdot).
#
# Usage:  ./app-cells-cfdot.sh <apps-file>
#   apps-file: one app name per line (blank lines and '#' comments ignored).
#              If the same app name exists in several orgs/spaces, every
#              match is listed.
#
# Designed to run on the opsman VM (same as pcf-health-check.sh). Read-only.
#
# How it works (vs app-cells.sh, which uses CF API instance stats):
#   1. cf curl resolves each app name -> app GUID (cfdot only knows GUIDs).
#   2. One 'bosh ssh' to a Diego cell runs 'cfdot cells' + 'cfdot actual-lrps'
#      in a login shell (cfdot is only on PATH in login shells). The BBS
#      returns every LRP cluster-wide, so a single call covers all apps.
#   3. actual-lrp process_guid = <app-guid(36)><version-guid>; the first 36
#      chars match the app. cell_id -> rep_address IP (cfdot cells) ->
#      BOSH instance name (bosh vms).
# This is the Diego control plane's own view of placement, so it also shows
# CLAIMED/CRASHED/UNCLAIMED instances the CF API stats may gloss over.

set -euo pipefail

DIEGO_CELL_GROUPS_RE="${DIEGO_CELL_GROUPS_RE:-^(compute|diego_cell|isolated_diego_cell)}"

APPS_FILE="${1:-}"
if [[ -z "$APPS_FILE" || ! -r "$APPS_FILE" ]]; then
  echo "usage: $0 <apps-file>   (one app name per line)" >&2
  exit 2
fi

# Authenticate the CLIs the same way the health check does.
[[ -z "${BOSH_ENVIRONMENT:-}" && -r "$HOME/env.sh" ]] && . "$HOME/env.sh" >/dev/null

for c in cf bosh jq; do
  command -v "$c" >/dev/null || { echo "ERROR: '$c' CLI not found on PATH" >&2; exit 2; }
done

# ---------------------------------------------------------------------------
# 1. Resolve app names -> GUIDs (+ org/space for the report).
# ---------------------------------------------------------------------------
declare -A APP_BY_GUID          # guid -> name<TAB>org<TAB>space
missing=0
while IFS= read -r app || [[ -n "$app" ]]; do
  app="${app#"${app%%[![:space:]]*}"}"; app="${app%"${app##*[![:space:]]}"}"
  [[ -z "$app" || "$app" == \#* ]] && continue
  enc="$(jq -rn --arg s "$app" '$s|@uri')"
  found=0
  while IFS=$'\t' read -r guid name org space; do
    [[ -z "$guid" ]] && continue
    APP_BY_GUID["$guid"]="${name}"$'\t'"${org}"$'\t'"${space}"
    found=1
  done < <(cf curl "/v3/apps?names=${enc}&include=space,space.organization&per_page=100" \
           | jq -r '
               (.included.spaces        // []) as $sp
             | (.included.organizations // []) as $org
             | (.resources // [])[]
             | . as $a
             | ($sp[]  | select(.guid == $a.relationships.space.data.guid)) as $s
             | ($org[] | select(.guid == $s.relationships.organization.data.guid)) as $o
             | [$a.guid, $a.name, $o.name, $s.name] | @tsv')
  if [[ $found -eq 0 ]]; then
    echo "WARN: app '$app' not found in any org/space" >&2
    missing=$((missing + 1))
  fi
done <"$APPS_FILE"
[[ ${#APP_BY_GUID[@]} -gt 0 ]] || { echo "ERROR: none of the listed apps were found." >&2; exit 2; }

# ---------------------------------------------------------------------------
# 2. Find a Diego cell to SSH to, and build IP -> BOSH instance map.
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
# 3. One login-shell SSH: cell registry + every actual LRP from the BBS.
#    (Same invocation pattern as pcf-health-check.sh section 5.)
# ---------------------------------------------------------------------------
echo "Querying the Diego BBS via ${cell_dep}/${cell_grp}/0 (cfdot)..." >&2
raw="$(timeout 150 bosh -d "$cell_dep" ssh "${cell_grp}/0" \
        -c 'bash -lc "echo @@CELLS; cfdot cells; echo @@LRP; cfdot actual-lrps"' 2>/dev/null \
        | sed -e 's/\r$//' -e 's/^[^|]*stdout | //')"
cells_json="$(awk '/^@@CELLS$/{f=1;next} /^@@LRP$/{f=0} f' <<<"$raw" | grep '^{' || true)"
lrp_json="$(awk '/^@@LRP$/{f=1;next} f' <<<"$raw" | grep '^{' || true)"
[[ -n "$lrp_json" ]] || { echo "ERROR: could not retrieve actual-lrps from the BBS via cfdot." >&2; exit 2; }

# cell_id -> BOSH instance (cfdot cells rep_address carries the cell IP)
declare -A INST_BY_CELL_ID
while IFS=$'\t' read -r cid addr; do
  [[ -z "$cid" ]] && continue
  ip="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$addr" | head -1 || true)"
  INST_BY_CELL_ID["$cid"]="${INST_BY_IP[$ip]:-unknown (rep ${addr})}"
done < <(jq -r '[.cell_id, (.rep_address // .rep_url // "")] | @tsv' <<<"$cells_json")

# ---------------------------------------------------------------------------
# 4. Filter the LRPs down to our app GUIDs and print.
# ---------------------------------------------------------------------------
guid_json="$(printf '%s\n' "${!APP_BY_GUID[@]}" | jq -R . | jq -s .)"

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf 'APP\tORG\tSPACE\tIDX\tSTATE\tCELL_ID\tDIEGO_CELL\n' >"$tmp"

declare -A CELL_COUNT
instances=0
while IFS=$'\t' read -r guid idx state cid; do
  [[ -z "$guid" ]] && continue
  IFS=$'\t' read -r name org space <<<"${APP_BY_GUID[$guid]}"
  if [[ -z "$cid" || "$cid" == "-" ]]; then
    cell='- (not placed)'
  else
    cell="${INST_BY_CELL_ID[$cid]:-unknown}"
    CELL_COUNT["$cell"]=$(( ${CELL_COUNT[$cell]:-0} + 1 ))
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$org" "$space" "$idx" "$state" "${cid:--}" "$cell" >>"$tmp"
  instances=$((instances + 1))
done < <(jq -r --argjson G "$guid_json" '
           .process_guid[0:36] as $g
         | select($G | index($g))
         | [$g, (.index|tostring), .state, (.cell_id // "-" | if . == "" then "-" else . end)]
         | @tsv' <<<"$lrp_json")

echo
column -t -s $'\t' "$tmp"
echo
echo "Summary: ${instances} instance(s) across ${#CELL_COUNT[@]} distinct Diego cell(s)."
for cell in "${!CELL_COUNT[@]}"; do
  printf '  %-60s %s instance(s)\n' "$cell" "${CELL_COUNT[$cell]}"
done | sort
[[ $missing -gt 0 ]] && { echo "WARN: ${missing} app(s) from the list were not found." >&2; exit 1; }
exit 0
