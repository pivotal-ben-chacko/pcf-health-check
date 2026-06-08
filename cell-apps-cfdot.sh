#!/usr/bin/env bash
#
# cell-apps-cfdot.sh -- list every app of one ORG residing on a given set of
# Diego cells.  (Inverse of app-cells-cfdot.sh: that one maps apps -> cells,
# this one maps cells -> apps, filtered to a single org.)
#
# Runs DIRECTLY ON A DIEGO CELL VM. No bosh CLI, no cf CLI, no jq -- only
# cfdot (present on every cell) and stock shell tools (awk/sed/grep).
#
# Usage:  ./cell-apps-cfdot.sh <org-name> <cells-file>
#   org-name:   CF organization name (exact, case-sensitive).
#   cells-file: one Diego cell per line -- either a cell_id (the instance
#               guid shown by 'cfdot cells' / 'bosh vms') or the cell's rep
#               IP address. Blank lines and '#' comments ignored.
#
# How it works:
#   - cfdot desired-lrps : TAS stamps each LRP's metric_tags with app_name /
#                          organization_name / space_name, so the org filter
#                          resolves from the BBS itself -- no CF API needed.
#                          Also carries 'instances' = total desired per app.
#   - cfdot cells        : cell_id -> rep IP / zone (validates the input list)
#   - cfdot actual-lrps  : process_guid + index + cell_id + state per instance
#   Output is grouped per requested cell: each cell is printed once with the
#   org's app instances on it, each as  <app>  <idx>/<total>  <state>
#   where idx is the instance index (0-based, as shown by 'cf app') and
#   total is the app's desired instance count.
#
# Notes:
#   - Stopped apps have no desired LRP, so they never appear -- correct,
#     since a stopped app resides on no cell.
#   - An app with several processes (web + workers) has one process_guid per
#     process; all share the same app_name tag, so each process's instances
#     are counted against that process's own desired total.
#
# Exit: 0 = ok; 1 = some listed cells were not found in the cell registry;
#       2 = usage / cfdot / BBS errors.

set -euo pipefail

ORG="${1:-}"
CELLS_FILE="${2:-}"
if [[ -z "$ORG" || -z "$CELLS_FILE" || ! -r "$CELLS_FILE" ]]; then
  echo "usage: $0 <org-name> <cells-file>   (one cell_id or rep IP per line)" >&2
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
# 0. Read the requested cell list.
# ---------------------------------------------------------------------------
req_file="$(mktemp)"; rows="$(mktemp)"
trap 'rm -f "$req_file" "$rows"' EXIT
n_req=0
while IFS= read -r c || [[ -n "$c" ]]; do
  c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"
  [[ -z "$c" || "$c" == \#* ]] && continue
  printf '%s\n' "$c" >>"$req_file"
  n_req=$((n_req + 1))
done <"$CELLS_FILE"
[[ $n_req -gt 0 ]] || { echo "ERROR: no cells in ${CELLS_FILE}." >&2; exit 2; }
sort -u "$req_file" -o "$req_file"

# ---------------------------------------------------------------------------
# 1. Query the BBS (all three are cluster-wide views; any one cell suffices).
# ---------------------------------------------------------------------------
echo "Querying the Diego BBS via cfdot..." >&2
desired="$(cfdot desired-lrps)"
cells="$(cfdot cells)"
lrps="$(cfdot actual-lrps)"
[[ -n "$cells" ]] || { echo "ERROR: 'cfdot cells' returned nothing -- BBS unreachable?" >&2; exit 2; }

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
# 2. Cell registry: cell_id -> IP/zone, plus IP -> cell_id so the input list
#    may use either form. Resolve the requested cells against it.
# ---------------------------------------------------------------------------
declare -A IP_BY_CELL_ID ZONE_BY_CELL_ID CELL_BY_IP
while IFS=$'\t' read -r cid addr zone; do
  [[ -z "$cid" ]] && continue
  ip="$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' <<<"$addr" | head -1 || true)"
  IP_BY_CELL_ID["$cid"]="${ip:-?}"
  ZONE_BY_CELL_ID["$cid"]="${zone:-?}"
  [[ -n "$ip" ]] && CELL_BY_IP["$ip"]="$cid"
done < <(awk "$AWK_LIB"'
  /^\{/ { print jstr("cell_id") "\t" jstr("rep_address") "\t" jstr("zone") }' <<<"$cells")

# (scalar counters alongside the assoc arrays: ${#ARR[@]} on an empty
#  declared array trips 'set -u' on bash < 4.4)
declare -A SELECTED
unresolved=0 n_sel=0
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  cid=""
  if [[ -n "${IP_BY_CELL_ID[$entry]:-}" ]]; then
    cid="$entry"
  elif [[ -n "${CELL_BY_IP[$entry]:-}" ]]; then
    cid="${CELL_BY_IP[$entry]}"
  else
    echo "WARN: '$entry' matches no registered Diego cell (cell_id or rep IP) -- skipped" >&2
    unresolved=$((unresolved + 1))
    continue
  fi
  [[ -z "${SELECTED[$cid]:-}" ]] && n_sel=$((n_sel + 1))
  SELECTED["$cid"]=1
done <"$req_file"
[[ $n_sel -gt 0 ]] || { echo "ERROR: none of the listed cells exist in the cell registry." >&2; exit 2; }

# ---------------------------------------------------------------------------
# 3. Desired LRPs filtered by org: process_guid -> app label + desired total.
# ---------------------------------------------------------------------------
declare -A PG_LABEL PG_TOTAL
n_pg=0
while IFS=$'\t' read -r pg an space total; do
  [[ -z "$pg" ]] && continue
  PG_LABEL["$pg"]="${an} (${space:-?})"
  PG_TOTAL["$pg"]="${total:-0}"
  n_pg=$((n_pg + 1))
done < <(awk -v org="$ORG" "$AWK_LIB"'
  /^\{/ {
    if (jtag("organization_name") == org)
      print jstr("process_guid") "\t" jtag("app_name") "\t" jtag("space_name") "\t" jnum("instances")
  }' <<<"$desired")
[[ $n_pg -gt 0 ]] || {
  echo "ERROR: no desired LRPs tagged with org '${ORG}' -- wrong org name, or org has no started apps." >&2
  exit 2
}

# ---------------------------------------------------------------------------
# 4. Walk the actual LRPs: keep instances of the org's apps that sit on one
#    of the selected cells.  rows: cid \t label \t idx \t state \t total \t pg
# ---------------------------------------------------------------------------
declare -A CELL_COUNT APP_SEL_COUNT
instances=0 cells_used=0 n_apps_sel=0
while IFS=$'\t' read -r pg idx state cid; do
  [[ -z "$pg" || -z "${PG_LABEL[$pg]:-}" || -z "${SELECTED[$cid]:-}" ]] && continue
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$cid" "${PG_LABEL[$pg]}" "$idx" "$state" "${PG_TOTAL[$pg]}" "$pg" >>"$rows"
  [[ -z "${CELL_COUNT[$cid]:-}" ]] && cells_used=$((cells_used + 1))
  [[ -z "${APP_SEL_COUNT[$pg]:-}" ]] && n_apps_sel=$((n_apps_sel + 1))
  CELL_COUNT["$cid"]=$(( ${CELL_COUNT[$cid]:-0} + 1 ))
  APP_SEL_COUNT["$pg"]=$(( ${APP_SEL_COUNT[$pg]:-0} + 1 ))
  instances=$((instances + 1))
done < <(awk "$AWK_LIB"'
  /^\{/ { print jstr("process_guid") "\t" jnum("index") "\t" jstr("state") "\t" jstr("cell_id") }' \
  <<<"$lrps")

# ---------------------------------------------------------------------------
# 5. Report: each requested cell once, its org app instances underneath.
# ---------------------------------------------------------------------------
echo
echo "Org '${ORG}' apps on ${n_sel} selected Diego cell(s):"
while IFS= read -r cid; do
  [[ -z "$cid" ]] && continue
  echo
  printf '%s  (%s, zone %s)  -- %s instance(s)\n' \
    "$cid" "${IP_BY_CELL_ID[$cid]:-?}" "${ZONE_BY_CELL_ID[$cid]:-?}" "${CELL_COUNT[$cid]:-0}"
  if [[ -z "${CELL_COUNT[$cid]:-}" ]]; then
    printf '  (no instances of org %s apps on this cell)\n' "$ORG"
    continue
  fi
  awk -F'\t' -v c="$cid" '$1 == c' "$rows" | sort -t$'\t' -k2,2 -k3,3n |
  while IFS=$'\t' read -r _ label idx state total _pg; do
    printf '  %-40s %s/%s  %s\n' "$label" "$idx" "$total" "$state"
  done
done < <(printf '%s\n' "${!SELECTED[@]}" | sort)

# ---------------------------------------------------------------------------
# 6. Summary: per-app totals on the selected cells vs desired.
# ---------------------------------------------------------------------------
echo
echo "Summary: ${instances} instance(s) of ${n_apps_sel} app process(es) in org '${ORG}'" \
     "on ${cells_used} of ${n_sel} selected cell(s)."
if [[ $n_apps_sel -gt 0 ]]; then
  echo "Per app (instances on selected cells / total desired):"
  while IFS= read -r pg; do
    [[ -z "$pg" ]] && continue
    printf '  %-40s %s/%s\n' "${PG_LABEL[$pg]}" "${APP_SEL_COUNT[$pg]}" "${PG_TOTAL[$pg]}"
  done < <(for pg in "${!APP_SEL_COUNT[@]}"; do
             printf '%s\t%s\n' "${PG_LABEL[$pg]}" "$pg"
           done | sort | cut -f2)
fi
[[ $unresolved -gt 0 ]] && { echo "WARN: ${unresolved} listed cell(s) were not found in the registry." >&2; exit 1; }
exit 0
