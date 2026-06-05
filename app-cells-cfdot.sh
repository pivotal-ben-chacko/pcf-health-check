#!/usr/bin/env bash
#
# app-cells-cfdot.sh -- identify the Diego cells a list of apps reside on.
#
# Runs DIRECTLY ON A DIEGO CELL VM. No bosh CLI, no cf CLI, no jq -- only
# cfdot (present on every cell) and stock shell tools (awk/sed/grep).
#
# Usage:  ./app-cells-cfdot.sh <apps-file>
#   apps-file: one app name per line (blank lines and '#' comments ignored).
#              If the same app name exists in several orgs/spaces, every
#              match is included (org/space shown to disambiguate).
#
# How it works:
#   - cfdot desired-lrps : TAS stamps each LRP's metric_tags with app_name /
#                          organization_name / space_name (the tags
#                          Loggregator uses), so app names resolve from the
#                          BBS itself -- no CF API needed.
#   - cfdot cells        : cell_id -> rep IP / zone
#   - cfdot actual-lrps  : process_guid + cell_id + state per app instance
#   Output is grouped per cell: each Diego cell is printed exactly once,
#   with every listed app residing on it (and its instance count).
#
# Notes:
#   - A stopped app has no desired LRP, so it reports as "not found" --
#     correct for this tool, since a stopped app resides on no cell.
#   - 'cfdot desired-lrps' returns full LRP definitions; on a foundation
#     with thousands of apps the first query may take a little while.

set -euo pipefail

APPS_FILE="${1:-}"
if [[ -z "$APPS_FILE" || ! -r "$APPS_FILE" ]]; then
  echo "usage: $0 <apps-file>   (one app name per line)" >&2
  exit 2
fi

# --- cfdot bootstrap: on a cell it's on PATH in login shells; otherwise the
# --- cfdot job ships a setup script that exports the BBS endpoint + certs.
if ! command -v cfdot >/dev/null 2>&1; then
  [[ -r /var/vcap/jobs/cfdot/bin/setup ]] && . /var/vcap/jobs/cfdot/bin/setup 2>/dev/null || true
  command -v cfdot >/dev/null 2>&1 || PATH="/var/vcap/packages/cfdot/bin:$PATH"
fi
command -v cfdot >/dev/null 2>&1 || {
  echo "ERROR: cfdot not found -- is this a Diego cell VM? (try a login shell, or 'source /var/vcap/jobs/cfdot/bin/setup')" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# 0. Read the requested app names.
# ---------------------------------------------------------------------------
names_file="$(mktemp)"; tmp="$(mktemp)"
trap 'rm -f "$names_file" "$tmp"' EXIT
n_names=0
while IFS= read -r app || [[ -n "$app" ]]; do
  app="${app#"${app%%[![:space:]]*}"}"; app="${app%"${app##*[![:space:]]}"}"
  [[ -z "$app" || "$app" == \#* ]] && continue
  printf '%s\n' "$app" >>"$names_file"
  n_names=$((n_names + 1))
done <"$APPS_FILE"
[[ $n_names -gt 0 ]] || { echo "ERROR: no app names in ${APPS_FILE}." >&2; exit 2; }
sort -u "$names_file" -o "$names_file"

# ---------------------------------------------------------------------------
# 1. Query the BBS (all three are cluster-wide views; any one cell suffices).
# ---------------------------------------------------------------------------
echo "Querying the Diego BBS via cfdot..." >&2
desired="$(cfdot desired-lrps)"
cells="$(cfdot cells)"
lrps="$(cfdot actual-lrps)"
[[ -n "$desired" ]] || { echo "ERROR: 'cfdot desired-lrps' returned nothing -- BBS unreachable?" >&2; exit 2; }

# --- tiny JSON field pullers (cfdot emits one JSON object per line; the BBS
# --- shapes are flat enough for anchored regex extraction -- no jq on cells).
#   jstr:  "key":"value"            jtag: "key":{"static":"value"}  (metric_tags)
#   jnum:  "key":123  (proto3 JSON omits zero values, so default is 0)
AWK_LIB='
function jstr(key,    re, s) {
  re = "\"" key "\":\"[^\"]*\""
  if (match($0, re)) { s = substr($0, RSTART, RLENGTH)
                       sub("^\"" key "\":\"", "", s); sub(/"$/, "", s); return s }
  return ""
}
function jtag(key,    re, s) {
  re = "\"" key "\":\\{\"static\":\"[^\"]*\""
  if (match($0, re)) { s = substr($0, RSTART, RLENGTH)
                       sub(/^.*"static":"/, "", s); sub(/"$/, "", s); return s }
  return jstr(key)
}
function jnum(key,    re, s) {
  re = "\"" key "\":[0-9]+"
  if (match($0, re)) { s = substr($0, RSTART, RLENGTH); sub(/^.*:/, "", s); return s }
  return "0"
}'

# ---------------------------------------------------------------------------
# 2. cell_id -> "IP (zone)" from the cell registry.
# ---------------------------------------------------------------------------
declare -A IP_BY_CELL_ID ZONE_BY_CELL_ID
while IFS=$'\t' read -r cid addr zone; do
  [[ -z "$cid" ]] && continue
  ip="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$addr" | head -1 || true)"
  IP_BY_CELL_ID["$cid"]="${ip:-?}"
  ZONE_BY_CELL_ID["$cid"]="${zone:-?}"
done < <(awk "$AWK_LIB"'
  /^\{/ { print jstr("cell_id") "\t" jstr("rep_address") "\t" jstr("zone") }' <<<"$cells")

# ---------------------------------------------------------------------------
# 3. Match requested names against desired-LRP metric tags.
#    process_guid -> "app (org/space)"
# ---------------------------------------------------------------------------
declare -A PG_LABEL FOUND_NAME
while IFS=$'\t' read -r pg an org space; do
  [[ -z "$pg" ]] && continue
  PG_LABEL["$pg"]="${an} (${org:-?}/${space:-?})"
  FOUND_NAME["$an"]=1
done < <(awk "$AWK_LIB"'
  NR == FNR { want[$0] = 1; next }                       # first file: app names
  /^\{/ {
    an = jtag("app_name")
    if (an != "" && (an in want))
      print jstr("process_guid") "\t" an "\t" jtag("organization_name") "\t" jtag("space_name")
  }' "$names_file" <(printf '%s\n' "$desired"))

missing=0
while IFS= read -r n; do
  if [[ -z "${FOUND_NAME[$n]:-}" ]]; then
    echo "WARN: app '$n' has no desired LRP in the BBS (not found, stopped, or has no instances)" >&2
    missing=$((missing + 1))
  fi
done <"$names_file"
[[ ${#PG_LABEL[@]} -gt 0 ]] || { echo "ERROR: none of the listed apps were found in the BBS." >&2; exit 2; }

# ---------------------------------------------------------------------------
# 4. Walk the actual LRPs and group instances by Diego cell.
# ---------------------------------------------------------------------------
SEP=$'\x1f'
declare -A CELL_TOTAL APPCELL
unplaced=""
instances=0
while IFS=$'\t' read -r pg idx state cid; do
  [[ -z "$pg" ]] && continue
  label="${PG_LABEL[$pg]:-}"
  [[ -z "$label" ]] && continue
  instances=$((instances + 1))
  if [[ -z "$cid" ]]; then
    unplaced+="  ${label} #${idx}: ${state} (no cell)"$'\n'
    continue
  fi
  CELL_TOTAL["$cid"]=$(( ${CELL_TOTAL[$cid]:-0} + 1 ))
  APPCELL["${cid}${SEP}${label}"]=$(( ${APPCELL["${cid}${SEP}${label}"]:-0} + 1 ))
done < <(awk "$AWK_LIB"'
  /^\{/ { print jstr("process_guid") "\t" jnum("index") "\t" jstr("state") "\t" jstr("cell_id") }' \
  <<<"$lrps")

# ---------------------------------------------------------------------------
# 5. Report: one row per distinct Diego cell.
# ---------------------------------------------------------------------------
printf 'CELL_ID\tCELL_IP\tZONE\tINSTANCES\tAPPS\n' >"$tmp"
while IFS= read -r cid; do
  [[ -z "$cid" ]] && continue
  apps=""
  while IFS= read -r k; do
    label="${k#*"$SEP"}"
    apps+="${apps:+, }${label} x${APPCELL[$k]}"
  done < <(printf '%s\n' "${!APPCELL[@]}" | grep -F "${cid}${SEP}" | sort)
  printf '%s\t%s\t%s\t%s\t%s\n' "$cid" "${IP_BY_CELL_ID[$cid]:-?}" \
    "${ZONE_BY_CELL_ID[$cid]:-?}" "${CELL_TOTAL[$cid]}" "$apps" >>"$tmp"
done < <(printf '%s\n' "${!CELL_TOTAL[@]}" | sort)

echo
if command -v column >/dev/null 2>&1; then column -t -s $'\t' "$tmp"; else cat "$tmp"; fi
echo
echo "Summary: ${instances} instance(s) of ${#PG_LABEL[@]} matched app(s) across ${#CELL_TOTAL[@]} distinct Diego cell(s)."
if [[ -n "$unplaced" ]]; then
  echo "Instances not currently placed on any cell:"
  printf '%s' "$unplaced"
fi
[[ $missing -gt 0 ]] && { echo "WARN: ${missing} app(s) from the list were not found." >&2; exit 1; }
exit 0
