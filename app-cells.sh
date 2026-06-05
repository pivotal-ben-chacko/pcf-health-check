#!/usr/bin/env bash
#
# app-cells.sh -- map CF apps to the Diego cells their instances run on.
#
# Usage:  ./app-cells.sh <apps-file>
#   apps-file: one app name per line (blank lines and '#' comments ignored).
#              If the same app name exists in several orgs/spaces, every
#              match is listed.
#
# Designed to run on the opsman VM (same as pcf-health-check.sh). Read-only.
# How it works: the CF API per-instance stats expose 'host' = the Diego cell
# IP; 'bosh vms' maps that IP back to the cell's BOSH instance name. No
# 'bosh ssh' / cfdot required.

set -euo pipefail

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
# Build IP -> BOSH instance map from 'bosh vms' across all deployments.
# ---------------------------------------------------------------------------
echo "Building cell map from 'bosh vms'..." >&2
declare -A INST_BY_IP
while IFS=$'\t' read -r inst ips; do
  for ip in ${ips//,/ }; do INST_BY_IP["$ip"]="$inst"; done
done < <(
  bosh deployments --json 2>/dev/null | jq -r '.Tables[0].Rows[].name' \
  | while read -r d; do
      bosh -d "$d" vms --json 2>/dev/null \
        | jq -r '.Tables[0].Rows[] | [.instance, .ips] | @tsv'
    done
)
[[ ${#INST_BY_IP[@]} -gt 0 ]] || { echo "ERROR: got no VMs from bosh -- is the director reachable?" >&2; exit 2; }

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
printf 'APP\tORG\tSPACE\tPROC\tIDX\tSTATE\tCELL_IP\tDIEGO_CELL\n' >"$tmp"

declare -A CELL_COUNT
instances=0 missing=0

while IFS= read -r app || [[ -n "$app" ]]; do
  # trim whitespace; skip blanks and comments
  app="${app#"${app%%[![:space:]]*}"}"; app="${app%"${app##*[![:space:]]}"}"
  [[ -z "$app" || "$app" == \#* ]] && continue

  enc="$(jq -rn --arg s "$app" '$s|@uri')"
  resp="$(cf curl "/v3/apps?names=${enc}&include=space,space.organization&per_page=100")"

  # guid, app name, org, space for every match of this name
  matches="$(jq -r '
      (.included.spaces        // []) as $sp
    | (.included.organizations // []) as $org
    | (.resources // [])[]
    | . as $a
    | ($sp[]  | select(.guid == $a.relationships.space.data.guid)) as $s
    | ($org[] | select(.guid == $s.relationships.organization.data.guid)) as $o
    | [$a.guid, $a.name, $o.name, $s.name] | @tsv' <<<"$resp")"

  if [[ -z "$matches" ]]; then
    echo "WARN: app '$app' not found in any org/space" >&2
    missing=$((missing + 1))
    continue
  fi

  while IFS=$'\t' read -r guid name org space; do
    # every process type (web, worker, ...) of the app
    while IFS=$'\t' read -r pguid ptype; do
      [[ -z "$pguid" ]] && continue
      # per-instance stats: index, state, host (= Diego cell IP)
      while IFS=$'\t' read -r idx istate host; do
        [[ -z "$idx" ]] && continue
        cell='-'
        [[ "$host" != '-' ]] && cell="${INST_BY_IP[$host]:-unknown ($host not in bosh vms)}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$name" "$org" "$space" "$ptype" "$idx" "$istate" "$host" "$cell" >>"$tmp"
        instances=$((instances + 1))
        [[ "$cell" != '-' ]] && CELL_COUNT["$cell"]=$(( ${CELL_COUNT[$cell]:-0} + 1 ))
      done < <(cf curl "/v3/processes/${pguid}/stats" \
                 | jq -r '(.resources // [])[]
                          | [(.index|tostring), .state,
                             (.host // "" | if . == "" then "-" else . end)]
                          | @tsv')
    done < <(cf curl "/v3/apps/${guid}/processes" \
               | jq -r '(.resources // [])[] | [.guid, .type] | @tsv')
  done <<<"$matches"
done <"$APPS_FILE"

echo
column -t -s $'\t' "$tmp"
echo
echo "Summary: ${instances} instance(s) across ${#CELL_COUNT[@]} distinct Diego cell(s)."
for cell in "${!CELL_COUNT[@]}"; do
  printf '  %-60s %s instance(s)\n' "$cell" "${CELL_COUNT[$cell]}"
done | sort
[[ $missing -gt 0 ]] && { echo "WARN: ${missing} app(s) from the list were not found." >&2; exit 1; }
exit 0
