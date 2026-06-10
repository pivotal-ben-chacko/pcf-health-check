#!/usr/bin/env bash
#
# cert-rotation-estimate.sh — find expiring certificates on a TAS/PCF foundation
# and estimate how long a certificate rotation will take.
#
# Run this ON the Operations Manager VM (it needs the om + bosh CLIs and the
# credentials exported by env.sh, exactly like pcf-health-check.sh):
#
#     ssh ubuntu@<opsman-ip>
#     ./cert-rotation-estimate.sh                # human output (colored)
#     ./cert-rotation-estimate.sh --no-color     # plain text for logs
#     ./cert-rotation-estimate.sh --json         # machine-readable summary
#     ./cert-rotation-estimate.sh --markdown     # Markdown report (stdout only)
#     ./cert-rotation-estimate.sh --days 90      # plan for certs expiring <=90 days
#     ./cert-rotation-estimate.sh --window 90d   # same, Ops Manager window syntax
#     IG_RATE_OVERRIDES="router=8:15" ./cert-rotation-estimate.sh  # per-IG VM time
#
# It is strictly READ-ONLY — it only reads cert metadata and VM counts; it never
# rotates anything or touches the foundation.
#
# ---------------------------------------------------------------------------
# Why the estimate is shaped the way it is
# ---------------------------------------------------------------------------
# A cert rotation costs one or more Ops Manager "Apply Changes" runs, and an
# Apply Changes is dominated by how many VMs BOSH has to recreate/restart:
#
#   * LEAF certificate (e.g. a router TLS cert, a UAA SAML cert): regenerate it
#     and run Apply Changes ONCE. Only the owning product's VMs are touched.
#
#   * CA certificate (the Ops Manager root CA, the CF "services TLS CA"): the
#     trust anchor lives on EVERY VM, so rotation is the standard three-phase
#     dance, each phase a separate, FOUNDATION-WIDE Apply Changes:
#         1. add the NEW CA   -> every VM now trusts old + new
#         2. regenerate leaf certs off the new CA / activate it
#         3. remove the OLD CA -> every VM trusts only the new
#
#   Not every CA is foundation-wide in all three phases, though:
#     * FOUNDATION CA (Ops Manager root CA, BOSH DNS CA, director NATS CA): the
#       trust anchor is on every VM, so ALL 3 phases are foundation-wide.
#     * TRUSTED-CERTS CA (the CF "services TLS CA"): the CA is distributed via the
#       BOSH director's *trusted certificates*, which propagate to every managed
#       VM — so phase 1 (add new CA to trusted certs) and phase 3 (remove old CA)
#       are FOUNDATION-WIDE, while phase 2 (regenerate the service leaf certs) only
#       touches the OWNING deployment. => 2 foundation applies + 1 scoped apply.
#     * DEPLOYMENT CA (e.g. a per-tile intermediate CA): all 3 phases hit only the
#       owning deployment.
#
# The per-VM cost is not uniform either: database/Galera nodes drain + resync (SST)
# and must roll serially, so they are costed higher (MIN_PER_VM_DB_*) than stateless
# VMs, per instance group. So the time model is:
#     apply_minutes(scope) = APPLY_OVERHEAD_MIN
#         + Σ over instance groups in scope: ceil(group_vms / in_flight) * rate
#       where rate / in_flight is the DB pair for database groups, else the default.
#     total = leaf_applies * apply_minutes(leaf deployments)
#           + Σ over CAs: fnd_phases*apply_minutes(foundation) + dep_phases*apply_minutes(owning dep)
# reported as a low–high range (MIN_PER_VM[_DB]_LOW/HIGH bound the per-VM cost).
#
# Tools: this uses `om` (already authenticated by env.sh). The same cert
# inventory is available from Broadcom's `maestro` CLI; swap the om curl calls
# for the equivalent maestro cert commands if you standardize on it.

set -uo pipefail

# ---------------------------------------------------------------------------
# Tunables (override via env). Times are in minutes.
# ---------------------------------------------------------------------------
# Planning horizon: certs expiring within this are candidates for rotation.
# Default "all" = no horizon limit (every deployed cert). Narrow it with --days N,
# --window <Nd|Nw|Nm|Ny> (Ops Manager 'expires_within' syntax), or ROTATE_WINDOW.
ROTATE_WINDOW=${ROTATE_WINDOW:-all}
# Severity windows inside the planning horizon.
CERT_CRIT_WINDOW=${CERT_CRIT_WINDOW:-1w}
CERT_WARN_WINDOW=${CERT_WARN_WINDOW:-1m}

# Records are \x1f-delimited (a non IFS-whitespace byte, so empty fields survive
# `read` — see the section-2 note). Defined here because section 1 uses it too.
SEP=$'\x1f'

# Apply Changes cost model. A VM's update DURATION comes from the rate (stateless
# MIN_PER_VM_* vs database MIN_PER_VM_DB_*, which drain + SST-resync and so cost
# more); how many update in PARALLEL (max_in_flight) and how many canaries go first
# come from each instance group's real BOSH `update` block when USE_MANIFEST_UPDATE
# is on (the MAX_IN_FLIGHT/DB_MAX_IN_FLIGHT below are only the fallback when the
# manifest can't be read). per-IG time = canaries*rate + ceil((n-canaries)/mif)*rate.
MIN_PER_VM_LOW=${MIN_PER_VM_LOW:-4}        # fast stateless VM update
MIN_PER_VM_HIGH=${MIN_PER_VM_HIGH:-10}     # slow stateless VM update (drain + post-start)
MAX_IN_FLIGHT=${MAX_IN_FLIGHT:-1}          # fallback parallelism for stateless groups
MIN_PER_VM_DB_LOW=${MIN_PER_VM_DB_LOW:-10} # DB node: drain + IST resync
MIN_PER_VM_DB_HIGH=${MIN_PER_VM_DB_HIGH:-20} # DB node: drain + full SST resync
DB_MAX_IN_FLIGHT=${DB_MAX_IN_FLIGHT:-1}    # fallback parallelism for DB groups
APPLY_OVERHEAD_MIN=${APPLY_OVERHEAD_MIN:-20}   # staging/compile/migrations per Apply
# Read real max_in_flight/canaries/serial per instance group from `bosh manifest`
# (needs python3 + PyYAML). 0 = use the MAX_IN_FLIGHT fallbacks above instead.
USE_MANIFEST_UPDATE=${USE_MANIFEST_UPDATE:-1}
# Instance groups costed at the DB rate (matched on the BOSH instance-group name).
DB_GROUPS_RE=${DB_GROUPS_RE:-'(mysql|database|galera|pxc|postgres|pgsql|rds|cockroach|^db[-_])'}
# Manual per-instance-group update-time overrides — highest precedence, beats the
# DB/stateless rates above. Space/comma-separated "pattern=low:high" (minutes);
# pattern is a case-insensitive regex on the BOSH instance-group name, first match
# wins. The instance group is the unit of update (all its VMs are identical), so
# this is how you hand-set the time for a particular VM type. Parallelism still
# comes from the manifest. e.g. IG_RATE_OVERRIDES="router=8:15 diego_cell=6:12"
IG_RATE_OVERRIDES="${IG_RATE_OVERRIDES:-}"

# Apply Changes counts per rotation kind.
CA_APPLY_COUNT=${CA_APPLY_COUNT:-3}        # FOUNDATION CA: 3 foundation-wide applies
LEAF_APPLY_COUNT=${LEAF_APPLY_COUNT:-1}    # leaf rotation: regenerate -> 1 apply
# TRUSTED-CERTS CA (services TLS CA): apply 1 ADDS the new CA to BOSH trusted certs
# (foundation-wide), apply 2 regenerates the service leaf certs (owning deployment
# only), apply 3 REMOVES the old CA from BOSH trusted certs (foundation-wide again).
SERVICES_CA_FND_APPLIES=${SERVICES_CA_FND_APPLIES:-2}   # the add + the remove
SERVICES_CA_DEP_APPLIES=${SERVICES_CA_DEP_APPLIES:-1}   # the leaf regeneration
DEP_CA_APPLIES=${DEP_CA_APPLIES:-3}        # DEPLOYMENT-scoped CA: 3 applies on its dep

# How CA rotations share Apply Changes:
#   0 = none: every CA costed in full, separately (worst case).
#   1 = default: the foundation-wide add/remove applies are shared across CAs, but
#       each deployment-scoped CA still costs its own applies.
#   2 = full (default): ONE shared 3-phase campaign on all tiles — generate all new
#       CAs (apply 1), regenerate all leaves incl. the leaf certs (apply 2), delete
#       all old CAs (apply 3). Deployment-scoped CAs and the leaf campaign fold into
#       those foundation-wide applies (a foundation apply recreates every VM anyway),
#       so the whole rotation is just `max_fnd_phases` foundation-wide applies.
CA_BATCH=${CA_BATCH:-2}

# Defer the old-CA removal: add the new CA to the BOSH trusted certs and regenerate
# leaves now; remove the OLD CA from trusted certs in a later maintenance window.
# OFF by default (0) — the estimate includes all 3 phases. Turn on with the --defer
# flag (or DEFER_CA_REMOVAL=1): the final foundation-wide "remove" Apply Changes is
# split out of the immediate estimate and reported as a deferred follow-up.
DEFER_CA_REMOVAL=${DEFER_CA_REMOVAL:-0}

# --- CA classification -----------------------------------------------------
# The deployed-certificates API names the rotation procedure per cert; a procedure
# matching CA_PROCEDURE_RE ("Standard CA Procedure", "Services TLS CA Procedure")
# is the 3-Apply CA dance. Leaf/SAML procedures take the 1-Apply path.
CA_PROCEDURE_RE=${CA_PROCEDURE_RE:-'CA Procedure'}
# Fallback CA detection on the label, for a cert with is_ca=true but no procedure.
CA_ROTATION_3X_RE=${CA_ROTATION_3X_RE:-'(root_ca|services.?tls.?ca|/tls_ca|trusted_certs|_ca$)'}
# Which scope model a CA takes. TRUSTED-CERTS (services TLS CA) is checked FIRST so
# it wins over the broad foundation pattern. FOUNDATION is the genuine all-VM trust
# anchors only; everything else falls through to DEPLOYMENT-scoped (owning product).
CA_TRUSTED_CERTS_RE=${CA_TRUSTED_CERTS_RE:-'(services.?tls.?ca|/services/tls_ca|Services TLS CA)'}
CA_FOUNDATION_RE=${CA_FOUNDATION_RE:-'(properties\.root_ca|properties\.nats_client_ca|bosh_dns/tls_ca|/opsmgr/.*tls_ca)'}

# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------
NO_COLOR=0; JSON_MODE=0; MD_MODE=0
FOUNDATION_NAME="${FOUNDATION_NAME:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-color) NO_COLOR=1;;
    --json) JSON_MODE=1; NO_COLOR=1;;
    --markdown|--md) MD_MODE=1; NO_COLOR=1;;
    --window) shift; ROTATE_WINDOW="${1:-$ROTATE_WINDOW}";;
    --window=*) ROTATE_WINDOW="${1#*=}";;
    --days) shift; ROTATE_WINDOW="${1:-0}d";;
    --days=*) ROTATE_WINDOW="${1#*=}d";;
    --all) ROTATE_WINDOW="all";;
    --defer) DEFER_CA_REMOVAL=1;;
    --no-defer) DEFER_CA_REMOVAL=0;;
    --foundation) shift; FOUNDATION_NAME="${1:-$FOUNDATION_NAME}";;
    --foundation=*) FOUNDATION_NAME="${1#*=}";;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
  esac
  shift
done
if [[ -t 1 && $NO_COLOR -eq 0 ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; BOLD=$'\e[1m'; RST=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; BOLD=""; RST=""
fi
# In --json / --markdown mode hide human output, keep real stdout on fd 3 for the doc.
if [[ $JSON_MODE -eq 1 || $MD_MODE -eq 1 ]]; then exec 3>&1 1>/dev/null; fi
# Markdown report buffers (accumulated during the run, rendered at the end).
MD_INV=""; MD_CERTS=""; MD_CAPLAN=""
md_esc(){ local s="${1//|/\\|}"; printf '%s' "${s//$'\n'/ }"; }   # escape table cells

# Parse IG_RATE_OVERRIDES ("pattern=low:high ...") into parallel arrays.
OV_PAT=(); OV_LO=(); OV_HI=()
for _ent in ${IG_RATE_OVERRIDES//,/ }; do
  [[ "$_ent" == *=*:* ]] || continue
  _rng="${_ent#*=}"
  OV_PAT+=("${_ent%%=*}"); OV_LO+=("${_rng%%:*}"); OV_HI+=("${_rng##*:}")
done

section(){ printf '\n%s%s== %s ==%s\n' "$BOLD" "$B" "$1" "$RST"; }
ok(){   printf '  %s[ OK ]%s %s\n' "$G" "$RST" "$1"; }
info(){ printf '  %s[INFO]%s %s\n' "$B" "$RST" "$1"; }
warn(){ printf '  %s[WARN]%s %s\n' "$Y" "$RST" "$1"; }
crit(){ printf '  %s[CRIT]%s %s\n' "$R" "$RST" "$1"; }
die(){  printf '\n%s[FATAL]%s %s\n' "$R" "$RST" "$1" >&2; exit 2; }

# minutes -> "2h 35m" (or "45m")
fmt_min(){ awk -v m="$1" 'BEGIN{ m=int(m+0.5); h=int(m/60); r=m%60;
  if(h>0) printf "%dh %02dm", h, r; else printf "%dm", r }'; }
# Minutes for ONE Apply Changes over the given deployments, costed per instance
# group. The per-VM RATE is the DB rate for database groups, else stateless. The
# PARALLELISM (max_in_flight, possibly "N%") and canary count come from the real
# manifest `update` block (IG_MIF/IG_CAN from §1) when present, else the global
# fallback. per-IG = canaries*rate + ceil((n-canaries)/max_in_flight)*rate.
# `which` selects the low or high per-VM cost.
scope_minutes(){ # which(low|high)  dep1 [dep2 ...]
  local which=$1; shift
  local nrate drate
  if [[ "$which" == high ]]; then nrate=$MIN_PER_VM_HIGH; drate=$MIN_PER_VM_DB_HIGH
  else nrate=$MIN_PER_VM_LOW; drate=$MIN_PER_VM_DB_LOW; fi
  local total=0 d key grp cnt isdb rate defmif mraw can ovrate oi
  for d in "$@"; do
    for key in "${!IG_VMS[@]}"; do
      [[ "$key" == "${d}${SEP}"* ]] || continue
      grp="${key#*$SEP}"; cnt="${IG_VMS[$key]}"; isdb="${IG_ISDB[$key]:-0}"
      # rate precedence: manual IG override > DB rate > stateless rate.
      ovrate=""
      for oi in "${!OV_PAT[@]}"; do
        grep -qiE "${OV_PAT[$oi]}" <<<"$grp" || continue
        ovrate="$([[ "$which" == high ]] && echo "${OV_HI[$oi]}" || echo "${OV_LO[$oi]}")"; break
      done
      if   [[ -n "$ovrate" ]]; then rate=$ovrate;  defmif=$MAX_IN_FLIGHT
      elif [[ "$isdb" == "1" ]]; then rate=$drate; defmif=$DB_MAX_IN_FLIGHT
      else rate=$nrate; defmif=$MAX_IN_FLIGHT; fi
      mraw="${IG_MIF[$key]:-}"; can="${IG_CAN[$key]:-}"
      total="$(awk -v t="$total" -v c="$cnt" -v r="$rate" -v mraw="$mraw" -v can="$can" -v dm="$defmif" 'BEGIN{
        if (mraw=="") mif=dm;
        else if (mraw ~ /%$/) { p=mraw; sub(/%$/,"",p); mif=int((c*p+99)/100) }
        else mif=mraw+0;
        if (mif<1) mif=1;
        cn=(can=="")?0:can+0; if(cn>c)cn=c; if(cn<0)cn=0;
        rest=c-cn; b=(rest>0)?int((rest+mif-1)/mif):0;
        printf "%.4f", t + cn*r + b*r }')"
    done
  done
  awk -v t="$total" -v ov="$APPLY_OVERHEAD_MIN" 'BEGIN{ printf "%.1f", ov + t }'
}
# n * a single-apply cost.
napply(){ awk -v n="$1" -v p="$2" 'BEGIN{ printf "%.1f", n*p }'; }

# ---------------------------------------------------------------------------
# Environment bootstrap — reuse env.sh just like pcf-health-check.sh.
# ---------------------------------------------------------------------------
if [[ -z "${BOSH_ENVIRONMENT:-}" ]]; then
  for f in "$(dirname "$0")/env.sh" "$HOME/env.sh" "./env.sh"; do
    [[ -f "$f" ]] && { info "Sourcing $f"; source "$f" >/dev/null 2>&1; break; }
  done
fi
command -v om   >/dev/null || die "om CLI not found on PATH."
command -v jq   >/dev/null || die "jq not found on PATH."
command -v bosh >/dev/null || die "bosh CLI not found on PATH."
# Maestro (optional) resolves a CA's signing topology — which deployments actually
# host the leaf certs it signs — so a global/credhub CA's deployment-scoped phase
# can be scoped precisely instead of defaulting to foundation-wide. USE_MAESTRO=0
# forces the om-only path. om has no equivalent of `maestro tp`.
HAVE_MAESTRO=0
[[ "${USE_MAESTRO:-1}" == "1" ]] && command -v maestro >/dev/null && HAVE_MAESTRO=1
# Per-instance-group update policy (max_in_flight/canaries/serial) from the BOSH
# manifest needs python3 + PyYAML; without them we fall back to the global defaults.
HAVE_PYYAML=0
[[ "$USE_MANIFEST_UPDATE" == "1" ]] && command -v python3 >/dev/null \
  && python3 -c 'import yaml' 2>/dev/null && HAVE_PYYAML=1
# Emits "<ig>\t<max_in_flight>\t<canaries>\t<serial>" per instance group, applying
# the manifest's per-IG `update` override on top of the global `update` block.
PY_UPDATE='
import sys, yaml
m = yaml.safe_load(sys.stdin) or {}
g = m.get("update") or {}
gmif, gcan, gser = g.get("max_in_flight"), g.get("canaries"), g.get("serial")
for ig in m.get("instance_groups", []):
    u = ig.get("update") or {}
    mif = u.get("max_in_flight", gmif)
    can = u.get("canaries", gcan)
    ser = u.get("serial", gser)
    print("%s\t%s\t%s\t%s" % (ig.get("name",""),
          "" if mif is None else mif, "" if can is None else can,
          "" if ser is None else str(ser).lower()))
'

# Deployments that host the leaf certs a CA signs (union over its signed leaves),
# via `maestro tp`. Echoes a space-separated list of live deployment names; empty
# if maestro is absent, errors, or names no deployment we can count.
maestro_ca_deps(){ # ca-name
  [[ $HAVE_MAESTRO -eq 1 ]] || return 0
  local d out=""
  while IFS= read -r d; do
    [[ -n "${VM_BY_DEP[$d]:-}" ]] && out+="${out:+ }$d"
  done < <(maestro tp --name "$1" 2>/dev/null | awk '
      /deployment_names:/ { c=1; next }
      c { if ($0 ~ /^[[:space:]]*-[[:space:]]/) { n=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",n); print n }
          else { c=0 } }' | sort -u)
  printf '%s' "$out"
}

printf '%s%sPCF Certificate Rotation Estimate%s\n' "$BOLD" "$B" "$RST"
printf 'Run as   : %s@%s   %s\n' "$(whoami)" "$(hostname)" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
# "all" / "infinite" = no horizon limit; everything else is an Ops Manager window.
WINDOW_IS_ALL=0; [[ "$ROTATE_WINDOW" == "all" || "$ROTATE_WINDOW" == "infinite" ]] && WINDOW_IS_ALL=1
HORIZON_TEXT="$([[ $WINDOW_IS_ALL -eq 1 ]] && echo 'all (no limit)' || echo "$ROTATE_WINDOW")"
printf 'Horizon  : certificates expiring within %s  |  topology: %s  |  update rules: %s\n' \
  "$HORIZON_TEXT" "$([[ $HAVE_MAESTRO -eq 1 ]] && echo 'maestro tp' || echo 'om only')" \
  "$([[ $HAVE_PYYAML -eq 1 ]] && echo 'bosh manifest' || echo 'global fallback')"

# ---------------------------------------------------------------------------
# Convert an Ops Manager window (Nd/Nw/Nm/Ny, or all) to days, for CA date math.
# ---------------------------------------------------------------------------
window_days(){ awk -v w="$1" 'BEGIN{
  if (w=="all" || w=="infinite" || w=="") { print 3650000; exit }   # effectively infinite
  n=w; sub(/[a-zA-Z]+$/,"",n); u=w; sub(/^[0-9]+/,"",u);
  if(u=="w") n=n*7; else if(u=="m") n=n*30; else if(u=="y") n=n*365;
  printf "%d", n }'; }
HORIZON_DAYS=$(window_days "$ROTATE_WINDOW")
NOW_EPOCH=$(date -u +%s)

# ---------------------------------------------------------------------------
# 1. Foundation inventory — deployments, friendly product names, VM counts.
# ---------------------------------------------------------------------------
section "1. Foundation inventory"

# guid -> product type (e.g. cf-abc123 -> cf). Deployment name == product guid.
declare -A PROD_TYPE
while IFS=$'\t' read -r guid ptype; do
  [[ -z "$guid" ]] && continue
  PROD_TYPE["$guid"]="$ptype"
done < <(om curl -s -p /api/v0/deployed/products 2>/dev/null \
          | jq -r '.[]? | [.guid, .type] | @tsv' 2>/dev/null)

# Live VMs per deployment, broken down per instance group (real VMs only — errands
# with no VM don't appear). The per-group split lets the cost model charge DB/Galera
# nodes at the higher serial rate. IG_VMS["<dep><SEP><group>"]=count.
declare -A VM_BY_DEP IG_VMS IG_ISDB IG_MIF IG_CAN IG_SERIAL
declare -A DB_VMS_BY_DEP    # db-classified VMs per deployment (for reporting)
DEPS=(); TOTAL_VMS=0; TOTAL_DB_VMS=0; N_PARALLEL_IG=0
while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  DEPS+=("$dep"); dep_total=0; dep_db=0
  while IFS=$'\t' read -r cnt grp; do
    [[ -z "$grp" || ! "$cnt" =~ ^[0-9]+$ ]] && continue
    IG_VMS["${dep}${SEP}${grp}"]=$cnt
    if grep -qiE "$DB_GROUPS_RE" <<<"$grp"; then
      IG_ISDB["${dep}${SEP}${grp}"]=1; dep_db=$((dep_db + cnt))
    else
      IG_ISDB["${dep}${SEP}${grp}"]=0
    fi
    dep_total=$((dep_total + cnt))
  done < <(bosh -d "$dep" --json vms 2>/dev/null \
            | jq -r '.Tables[0].Rows[]? | (.instance | split("/")[0])' 2>/dev/null \
            | sort | uniq -c | awk '{print $1"\t"$2}')
  # Real per-IG update policy from the manifest (one fetch per deployment).
  if [[ $HAVE_PYYAML -eq 1 ]]; then
    while IFS=$'\t' read -r grp mif can ser; do
      [[ -z "$grp" || -z "${IG_VMS[${dep}${SEP}${grp}]:-}" ]] && continue
      IG_MIF["${dep}${SEP}${grp}"]="$mif"; IG_CAN["${dep}${SEP}${grp}"]="$can"
      IG_SERIAL["${dep}${SEP}${grp}"]="$ser"
      [[ "$ser" == "false" && "${IG_VMS[${dep}${SEP}${grp}]:-0}" -gt 0 ]] && N_PARALLEL_IG=$((N_PARALLEL_IG+1))
    done < <(bosh -d "$dep" manifest 2>/dev/null | python3 -c "$PY_UPDATE" 2>/dev/null)
  fi
  VM_BY_DEP["$dep"]=$dep_total; DB_VMS_BY_DEP["$dep"]=$dep_db
  TOTAL_VMS=$((TOTAL_VMS + dep_total)); TOTAL_DB_VMS=$((TOTAL_DB_VMS + dep_db))
done < <(bosh --json deployments 2>/dev/null | jq -r '.Tables[0].Rows[]?.name' 2>/dev/null)

[[ $TOTAL_VMS -gt 0 ]] || die "Could not count any BOSH VMs — is the director reachable (source env.sh)?"
info "Deployments: ${#VM_BY_DEP[@]} | total live VMs: ${TOTAL_VMS} (${TOTAL_DB_VMS} DB node(s) costed serially)"
for dep in "${DEPS[@]}"; do
  dbnote=""; [[ "${DB_VMS_BY_DEP[$dep]:-0}" -gt 0 ]] && dbnote=", ${DB_VMS_BY_DEP[$dep]} DB"
  info "  ${dep} (${PROD_TYPE[$dep]:-?}): ${VM_BY_DEP[$dep]} VM(s)${dbnote}"
done
[[ $HAVE_PYYAML -eq 1 && $N_PARALLEL_IG -gt 0 ]] && info "Note: ${N_PARALLEL_IG} instance group(s) have serial:false — they MAY update in parallel with peers, shortening real time below this (conservative) serial estimate."

# ---------------------------------------------------------------------------
# 2. Expiring certificates (Ops Manager deployed certs + the root CA).
# ---------------------------------------------------------------------------
section "2. Expiring certificates ($([[ $WINDOW_IS_ALL -eq 1 ]] && echo 'all' || echo "<= ${ROTATE_WINDOW}"))"

# Severity membership: keys (product_guid|property_reference) that fall in the
# tighter crit/warn windows. The unfiltered list has null dates on this opsman,
# so we lean on expires_within and tag by the smallest window each cert hits.
# A cert's label is its property_reference (ops_manager certs) or variable_path
# (credhub certs); one or the other is null/empty. Its key is product_guid|label.
# Some certs (e.g. the Services TLS CA) ship product_guid="" — an EMPTY string, so
# jq's `//` (which only fires on null/false) won't substitute it. These shared defs
# coalesce empty *and* null, and the same defs drive the severity-window sets and
# the planning set so the keys line up. Records use a \x1f delimiter, not a tab:
# tab is IFS-whitespace, so `read` would trim an empty leading field and shift the
# columns — exactly what mis-parsed the empty-guid Services TLS CA as a leaf.
JQ_DEFS='
  def lbl: [.property_reference, .variable_path] | map(select(. != null and . != "")) | (.[0] // "-");
  def gid: (.product_guid // "") | if . == "" then "-" else . end;
  def c:   (. // "-") | tostring | if . == "" then "-" else . end;'
crit_keys="$(om curl -s -p "/api/v0/deployed/certificates?expires_within=${CERT_CRIT_WINDOW}" 2>/dev/null \
  | jq -r "${JQ_DEFS} .certificates[]? | [gid, lbl] | join(\"|\")" 2>/dev/null)"
warn_keys="$(om curl -s -p "/api/v0/deployed/certificates?expires_within=${CERT_WARN_WINDOW}" 2>/dev/null \
  | jq -r "${JQ_DEFS} .certificates[]? | [gid, lbl] | join(\"|\")" 2>/dev/null)"

# Planning set: everything expiring within the horizon, with the metadata we need.
# The API names the rotation procedure per cert — that's what tells leaf from CA.
# With "all", drop the expires_within filter and take every deployed certificate.
CERT_QUERY="/api/v0/deployed/certificates"
[[ $WINDOW_IS_ALL -eq 1 ]] || CERT_QUERY="${CERT_QUERY}?expires_within=${ROTATE_WINDOW}"
certs_tsv="$(om curl -s -p "$CERT_QUERY" 2>/dev/null \
  | jq -r "${JQ_DEFS} .certificates[]? | [
        gid, (.is_ca // false | tostring), lbl,
        (.location|c), (.valid_until // \"\"), (.rotation_procedure_name // \"\")
      ] | join(\"\")" 2>/dev/null)"

# Accumulators for the estimate.
N_LEAF=0; N_CA=0; N_CRIT=0; N_WARN=0
declare -A LEAF_DEPS         # deployment -> 1, deployments touched by leaf rotations
declare -A LEAF_BY_DEP       # deployment -> leaf-cert count (for the markdown report)
# Parallel CA record arrays, one entry per CA rotation (consumed by §3 / report).
CA_MODEL=(); CA_DEP=(); CA_LABEL=(); CA_SEV=(); CA_EXP=()

emit_sev(){ # level message  -> calls the right logger and bumps counters
  case "$1" in CRIT) crit "$2"; N_CRIT=$((N_CRIT+1));;
               WARN) warn "$2"; N_WARN=$((N_WARN+1));;
               *)    info "$2";; esac; }

# Classify a CA's rotation SCOPE model from its label/procedure. Echoes the model;
#   TRUSTED    services TLS CA — add/remove via BOSH trusted certs (foundation),
#              leaf regen on the owning deployment. (checked first: it would also
#              match the broad foundation pattern, but its model is different.)
#   FOUNDATION genuine all-VM trust anchor — every phase foundation-wide.
#   DEPLOYMENT everything else — every phase on the owning deployment only.
ca_scope_model(){ # label proc
  if grep -qiE "$CA_TRUSTED_CERTS_RE" <<<"$1 $2"; then echo TRUSTED
  elif grep -qiE "$CA_FOUNDATION_RE" <<<"$1"; then echo FOUNDATION
  else echo DEPLOYMENT; fi
}
# Human description of a CA's apply plan.
ca_plan_text(){ # model dep
  case "$1" in
    FOUNDATION) echo "${CA_APPLY_COUNT}x foundation-wide";;
    TRUSTED)    echo "${SERVICES_CA_FND_APPLIES}x foundation-wide (BOSH trusted-certs add+remove) + ${SERVICES_CA_DEP_APPLIES}x ${2}";;
    DEPLOYMENT) echo "${DEP_CA_APPLIES}x ${2}";;
  esac
}

if [[ -z "$certs_tsv" ]]; then
  ok "No deployed certificates expire within ${ROTATE_WINDOW}."
else
  while IFS="$SEP" read -r pguid is_ca pref loc vuntil proc; do
    [[ -z "$pref" || "$pref" == "-" ]] && continue
    key="${pguid}|${pref}"
    sev="INFO"
    grep -qxF "$key" <<<"$warn_keys" && sev="WARN"
    grep -qxF "$key" <<<"$crit_keys" && sev="CRIT"
    ptxt="${proc:+ {${proc}}}"
    # Friendly product label; empty-guid certs are foundation-global credhub CAs.
    prod="${PROD_TYPE[$pguid]:-$pguid}"; [[ "$pguid" == "-" ]] && prod="credhub-global"

    # CA rotation (3 Apply Changes) or leaf (1)? The API's rotation_procedure_name
    # is authoritative; fall back to is_ca / the label regex if it's absent.
    if { [[ -n "$proc" ]] && grep -qiE "$CA_PROCEDURE_RE" <<<"$proc"; } \
       || [[ "$is_ca" == "true" ]] || grep -qiE "$CA_ROTATION_3X_RE" <<<"$pref"; then
      N_CA=$((N_CA+1))
      model="$(ca_scope_model "$pref" "$proc")"
      # Resolve the deployment(s) for the deployment-scoped phase(s):
      #   1. maestro tp — the deployments that actually host this CA's leaf certs
      #   2. else the cert's own product_guid, if it names a live deployment
      #   3. else foundation-wide (conservative; can't scope it any tighter)
      dep="__FND__"; depnote=""
      if [[ "$model" != FOUNDATION ]]; then
        mdeps="$(maestro_ca_deps "$pref")"
        if [[ -n "$mdeps" ]]; then dep="$mdeps"; depnote=" (scoped via maestro tp)"
        elif [[ -n "${VM_BY_DEP[$pguid]:-}" ]]; then dep="$pguid"
        else depnote=" (owning deployment unknown — leaf-regen costed foundation-wide)"; fi
      fi
      CA_MODEL+=("$model"); CA_DEP+=("$dep"); CA_LABEL+=("$pref"); CA_SEV+=("$sev"); CA_EXP+=("${vuntil:-—}")
      depname="$dep"; [[ "$dep" == "__FND__" ]] && depname="foundation"; depname="${depname// /, }"
      emit_sev "$sev" "CA   ${pref} [${prod}] — ${model}: $(ca_plan_text "$model" "$depname") Apply Changes${vuntil:+, expires ${vuntil}}${ptxt}${depnote}"
    else
      N_LEAF=$((N_LEAF+1))
      dep="$pguid"
      if [[ -n "${VM_BY_DEP[$dep]:-}" ]]; then
        LEAF_DEPS["$dep"]=1; LEAF_BY_DEP["$dep"]=$(( ${LEAF_BY_DEP[$dep]:-0} + 1 ))
      else
        # e.g. the BOSH director's own certs (p-bosh) — not a countable deployment,
        # so excluded from the leaf cost scope; tallied separately for the report.
        LEAF_BY_DEP["${prod} (not VM-counted)"]=$(( ${LEAF_BY_DEP["${prod} (not VM-counted)"]:-0} + 1 ))
      fi
      vmc="${VM_BY_DEP[$dep]:-?}"
      emit_sev "$sev" "leaf ${pref} [${prod}] — ${dep} (${vmc} VMs, ${LEAF_APPLY_COUNT}x Apply Changes)${vuntil:+, expires ${vuntil}}${ptxt}"
    fi
  done <<<"$certs_tsv"
fi

# Ops Manager root CA(s) — the certificate_authorities endpoint DOES carry an
# expiry date, so check it directly even if it isn't in the deployed-cert list.
while IFS=$'\t' read -r guid active expires; do
  [[ -z "$guid" || "$active" != "true" || -z "$expires" ]] && continue
  exp_epoch="$(date -u -d "$expires" +%s 2>/dev/null)" || continue
  days=$(( (exp_epoch - NOW_EPOCH) / 86400 ))
  [[ $days -gt $HORIZON_DAYS ]] && continue
  N_CA=$((N_CA+1))
  rsev="INFO"
  if   [[ $days -le $(window_days "$CERT_CRIT_WINDOW") ]]; then rsev="CRIT"
  elif [[ $days -le $(window_days "$CERT_WARN_WINDOW") ]]; then rsev="WARN"; fi
  CA_MODEL+=("FOUNDATION"); CA_DEP+=("__FND__"); CA_LABEL+=("opsman-root-ca:${guid:0:8}"); CA_SEV+=("$rsev"); CA_EXP+=("$expires")
  msg="Ops Manager ROOT CA ${guid:0:8}… expires in ${days}d (${expires}) — FOUNDATION: ${CA_APPLY_COUNT}x foundation-wide Apply Changes over ${TOTAL_VMS} VMs"
  case "$rsev" in CRIT) crit "$msg"; N_CRIT=$((N_CRIT+1));; WARN) warn "$msg"; N_WARN=$((N_WARN+1));; *) info "$msg";; esac
done < <(om curl -s -p /api/v0/certificate_authorities 2>/dev/null \
          | jq -r '.certificate_authorities[]? | [.guid, .active, (.expires_on // "")] | @tsv' 2>/dev/null)

# ---------------------------------------------------------------------------
# 3. Rotation time estimate.
# ---------------------------------------------------------------------------
section "3. Estimated rotation time"

# Leaf campaign: ONE Apply Changes over the union of affected deployments, costed
# per instance group (so DB leaf certs are charged at the serial DB rate).
leaf_deps=("${!LEAF_DEPS[@]}")
LEAF_SCOPE_VMS=0
for d in "${leaf_deps[@]}"; do LEAF_SCOPE_VMS=$((LEAF_SCOPE_VMS + ${VM_BY_DEP[$d]:-0})); done

leaf_lo=0; leaf_hi=0
if [[ $N_LEAF -gt 0 ]]; then
  leaf_lo="$(napply "$LEAF_APPLY_COUNT" "$(scope_minutes low  "${leaf_deps[@]}")")"
  leaf_hi="$(napply "$LEAF_APPLY_COUNT" "$(scope_minutes high "${leaf_deps[@]}")")"
  info "Leaf certs: ${N_LEAF} across ${#leaf_deps[@]} deployment(s), ${LEAF_SCOPE_VMS} VMs"
  info "  ${LEAF_APPLY_COUNT}x Apply Changes => $(fmt_min "$leaf_lo") – $(fmt_min "$leaf_hi")"
fi

# CA campaign: per CA, foundation-wide phases over ALL deployments + deployment-
# scoped phases over the owning deployment. The cost of one foundation-wide Apply
# is the same regardless of which CA triggers it, so when batched (default) the
# foundation applies are shared once across every CA (you add all the new CAs, then
# remove all the old ones, in common Apply Changes); the deployment-scoped leaf-
# regen phases stay per-CA. Un-batched (CA_BATCH=0) costs every CA in full.
FND_LO="$(scope_minutes low  "${DEPS[@]}")"   # one foundation-wide Apply (low)
FND_HI="$(scope_minutes high "${DEPS[@]}")"   # one foundation-wide Apply (high)
nf=0; nt=0; nd=0; max_fnd_phases=0
ca_dep_lo=0; ca_dep_hi=0; nonbatch_lo=0; nonbatch_hi=0
for i in "${!CA_MODEL[@]}"; do
  model="${CA_MODEL[$i]}"; dep="${CA_DEP[$i]}"
  case "$model" in
    FOUNDATION) fph=$CA_APPLY_COUNT;        dph=0;                     nf=$((nf+1));;
    TRUSTED)    fph=$SERVICES_CA_FND_APPLIES; dph=$SERVICES_CA_DEP_APPLIES; nt=$((nt+1));;
    DEPLOYMENT) fph=0;                      dph=$DEP_CA_APPLIES;       nd=$((nd+1));;
  esac
  # dep may be "__FND__" or a space-separated deployment list (from maestro).
  if [[ "$dep" == "__FND__" ]]; then od_lo="$FND_LO"; od_hi="$FND_HI"
  else read -ra _depsarr <<<"$dep"
       od_lo="$(scope_minutes low  "${_depsarr[@]}")"; od_hi="$(scope_minutes high "${_depsarr[@]}")"; fi
  (( fph > max_fnd_phases )) && max_fnd_phases=$fph
  ca_dep_lo="$(awk -v a="$ca_dep_lo" -v d="$dph" -v p="$od_lo" 'BEGIN{printf "%.4f", a+d*p}')"
  ca_dep_hi="$(awk -v a="$ca_dep_hi" -v d="$dph" -v p="$od_hi" 'BEGIN{printf "%.4f", a+d*p}')"
  nonbatch_lo="$(awk -v a="$nonbatch_lo" -v f="$fph" -v fp="$FND_LO" -v d="$dph" -v p="$od_lo" 'BEGIN{printf "%.4f", a+f*fp+d*p}')"
  nonbatch_hi="$(awk -v a="$nonbatch_hi" -v f="$fph" -v fp="$FND_HI" -v d="$dph" -v p="$od_hi" 'BEGIN{printf "%.4f", a+f*fp+d*p}')"
done

# Deferred removal: the final foundation-wide "remove old CA from trusted certs"
# apply can be done in a later window. Pull it out of the immediate foundation
# phases (batched modes only) and report it as a follow-up.
imm_fnd=$max_fnd_phases; defer_lo=0; defer_hi=0
if [[ "$DEFER_CA_REMOVAL" == "1" && "$CA_BATCH" != "0" && $max_fnd_phases -gt 0 ]]; then
  imm_fnd=$((max_fnd_phases - 1)); defer_lo="$FND_LO"; defer_hi="$FND_HI"
fi

ca_lo=0; ca_hi=0; leaf_absorbed=0
if [[ ${#CA_MODEL[@]} -gt 0 ]]; then
  if [[ "$CA_BATCH" == "0" ]]; then
    ca_lo="$(awk -v x="$nonbatch_lo" 'BEGIN{printf "%.1f", x}')"
    ca_hi="$(awk -v x="$nonbatch_hi" 'BEGIN{printf "%.1f", x}')"
  elif [[ "$CA_BATCH" == "2" && $max_fnd_phases -gt 0 ]]; then
    # Full batch: one shared campaign on all tiles. Add all new CAs + regen all
    # leaves (incl. leaf certs) fold into the immediate foundation-wide applies;
    # the old-CA removal is the deferred apply when DEFER_CA_REMOVAL=1.
    ca_lo="$(awk -v f="$imm_fnd" -v fp="$FND_LO" 'BEGIN{printf "%.1f", f*fp}')"
    ca_hi="$(awk -v f="$imm_fnd" -v fp="$FND_HI" 'BEGIN{printf "%.1f", f*fp}')"
    leaf_absorbed=1
  else
    # Shared foundation applies; deployment-scoped CAs costed on top (also the
    # CA_BATCH=2 fallback when there is no foundation-wide apply to fold into).
    ca_lo="$(awk -v f="$imm_fnd" -v fp="$FND_LO" -v d="$ca_dep_lo" 'BEGIN{printf "%.1f", f*fp+d}')"
    ca_hi="$(awk -v f="$imm_fnd" -v fp="$FND_HI" -v d="$ca_dep_hi" 'BEGIN{printf "%.1f", f*fp+d}')"
  fi
  info "CA certs: ${#CA_MODEL[@]} — ${nf} foundation, ${nt} services/trusted-certs, ${nd} deployment-scoped"
  for i in "${!CA_MODEL[@]}"; do
    dn="${CA_DEP[$i]}"; [[ "$dn" == "__FND__" ]] && dn="foundation"; dn="${dn// /, }"
    info "  - ${CA_LABEL[$i]} [${CA_MODEL[$i]}]: $(ca_plan_text "${CA_MODEL[$i]}" "$dn") Apply Changes"
  done
  case "$CA_BATCH" in
    0) info "  Un-batched: each CA's foundation applies costed separately";;
    2) if [[ $leaf_absorbed -eq 1 ]]; then
         info "  Full batch: ${imm_fnd}x foundation-wide Apply on all tiles ($(fmt_min "$FND_LO")–$(fmt_min "$FND_HI") each, ${TOTAL_VMS} VMs) — all CAs + leaf regen folded in"
       else
         info "  Full batch requested but no foundation-wide apply present — costing per-deployment instead"
       fi;;
    *) info "  Batched: ${imm_fnd}x shared foundation-wide Apply ($(fmt_min "$FND_LO")–$(fmt_min "$FND_HI") each, ${TOTAL_VMS} VMs) + per-deployment leaf-regen";;
  esac
  info "  => $(fmt_min "$ca_lo") – $(fmt_min "$ca_hi")"
  if [[ "$DEFER_CA_REMOVAL" == "1" && $(awk -v x="$defer_hi" 'BEGIN{print (x>0)}') -eq 1 ]]; then
    info "  Deferred (later window): 1x foundation-wide Apply to remove the old CA(s) from trusted certs => $(fmt_min "$defer_lo") – $(fmt_min "$defer_hi")"
  fi
fi

# In a full batch the leaf-cert regen rides the shared foundation apply (#2), so it
# adds nothing on top; otherwise it's its own campaign.
leaf_total_lo="$leaf_lo"; leaf_total_hi="$leaf_hi"
[[ $leaf_absorbed -eq 1 ]] && { leaf_total_lo=0; leaf_total_hi=0; }
TOTAL_LO="$(awk -v a="$leaf_total_lo" -v b="$ca_lo" 'BEGIN{printf "%.1f", a+b}')"
TOTAL_HI="$(awk -v a="$leaf_total_hi" -v b="$ca_hi" 'BEGIN{printf "%.1f", a+b}')"

section "Summary"
printf '  %sExpiring certs in horizon%s : %d (CRIT %d · WARN %d) — %d leaf, %d CA\n' \
  "$BOLD" "$RST" "$((N_LEAF+N_CA))" "$N_CRIT" "$N_WARN" "$N_LEAF" "$N_CA"
if [[ $((N_LEAF+N_CA)) -eq 0 ]]; then
  ok "Nothing to rotate within ${ROTATE_WINDOW}."
else
  notetxt=""
  if [[ "${leaf_absorbed:-0}" -eq 1 ]]; then
    notetxt="  (full batch: all ${N_CA} CA(s) + ${N_LEAF} leaf cert(s) in ${imm_fnd} foundation-wide applies)"
  elif [[ $nt -gt 0 ]]; then
    notetxt="  (services TLS CA = ${SERVICES_CA_FND_APPLIES} foundation + ${SERVICES_CA_DEP_APPLIES} deployment applies)"
  fi
  printf '  %sEstimated rotation time%s   : %s – %s%s\n' \
    "$BOLD" "$RST" "$(fmt_min "$TOTAL_LO")" "$(fmt_min "$TOTAL_HI")" "$notetxt"
  if [[ "$DEFER_CA_REMOVAL" == "1" && $(awk -v x="$defer_hi" 'BEGIN{print (x>0)}') -eq 1 ]]; then
    printf '  %sDeferred (remove old CA)%s  : %s – %s  (later maintenance window)\n' \
      "$BOLD" "$RST" "$(fmt_min "$defer_lo")" "$(fmt_min "$defer_hi")"
  fi
  mifsrc="$([[ $HAVE_PYYAML -eq 1 ]] && echo 'per-IG max_in_flight/canaries from bosh manifest' || echo "global fallback ${MAX_IN_FLIGHT}/${DB_MAX_IN_FLIGHT} in flight")"
  info "Model: ${APPLY_OVERHEAD_MIN}m overhead/apply; stateless ${MIN_PER_VM_LOW}-${MIN_PER_VM_HIGH}m/VM, DB ${MIN_PER_VM_DB_LOW}-${MIN_PER_VM_DB_HIGH}m/node; ${mifsrc}. Excludes change-window/approval gaps."
fi

# ---------------------------------------------------------------------------
# JSON summary (CI gate). Written to the real stdout (fd 3) in --json mode.
# ---------------------------------------------------------------------------
if [[ $JSON_MODE -eq 1 ]]; then
  jq -n \
    --argjson total_vms "$TOTAL_VMS" --argjson db_vms "$TOTAL_DB_VMS" \
    --argjson leaf "$N_LEAF" --argjson ca "$N_CA" \
    --argjson crit "$N_CRIT" --argjson warn "$N_WARN" \
    --argjson leaf_vms "$LEAF_SCOPE_VMS" \
    --argjson nf "$nf" --argjson nt "$nt" --argjson nd "$nd" \
    --argjson fnd_phases "$max_fnd_phases" \
    --argjson lo "$TOTAL_LO" --argjson hi "$TOTAL_HI" \
    --argjson ca_lo "$ca_lo" --argjson ca_hi "$ca_hi" \
    --argjson leaf_lo "$leaf_lo" --argjson leaf_hi "$leaf_hi" \
    --arg batch "$CA_BATCH" --arg window "$ROTATE_WINDOW" \
    --arg topo "$([[ $HAVE_MAESTRO -eq 1 ]] && echo 'maestro' || echo 'om')" \
    --arg upol "$([[ $HAVE_PYYAML -eq 1 ]] && echo 'bosh_manifest' || echo 'global_fallback')" \
    --argjson parallel_igs "${N_PARALLEL_IG:-0}" \
    --argjson leaf_absorbed "${leaf_absorbed:-0}" \
    --argjson imm_fnd "${imm_fnd:-0}" \
    --argjson defer_lo "${defer_lo:-0}" --argjson defer_hi "${defer_hi:-0}" \
    --arg defer "$DEFER_CA_REMOVAL" \
    '{
       window: $window, topology_source: $topo,
       update_policy_source: $upol, serial_false_instance_groups: $parallel_igs,
       total_vms: $total_vms, db_vms: $db_vms,
       ca_batch_mode: ($batch|tonumber), leaf_folded_into_ca: ($leaf_absorbed==1),
       defer_old_ca_removal: ($defer=="1"), immediate_foundation_applies: $imm_fnd,
       expiring: { leaf: $leaf, ca: $ca, crit: $crit, warn: $warn },
       ca_models: { foundation: $nf, services_trusted_certs: $nt, deployment: $nd },
       shared_foundation_applies: $fnd_phases,
       leaf_scope_vms: $leaf_vms,
       estimate_minutes: { leaf: { low: $leaf_lo, high: $leaf_hi },
                           ca:   { low: $ca_lo,   high: $ca_hi },
                           total:{ low: $lo,      high: $hi },
                           deferred_removal: { low: $defer_lo, high: $defer_hi } },
       estimate_human: { low: "'"$(fmt_min "$TOTAL_LO")"'", high: "'"$(fmt_min "$TOTAL_HI")"'" }
     }' >&3
fi

# ---------------------------------------------------------------------------
# Markdown report. Written to the real stdout (fd 3) in --markdown mode.
# ---------------------------------------------------------------------------
if [[ $MD_MODE -eq 1 ]]; then
  badge(){ case "$1" in CRIT) printf '❌ CRIT';; WARN) printf '⚠️ WARN';; *) printf 'ℹ️ info';; esac; }
  title="PCF${FOUNDATION_NAME:+ $FOUNDATION_NAME} Certificate Rotation Estimate"
  {
    printf '# %s\n\n' "$title"
    printf -- '- **Director:** `%s`\n' "${BOSH_ENVIRONMENT:-?}"
    printf -- '- **Generated:** %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf -- '- **Horizon:** %s\n' "$([[ $WINDOW_IS_ALL -eq 1 ]] && echo 'all certificates (no expiry limit)' || echo "certificates expiring within \`${ROTATE_WINDOW}\`")"
    printf -- '- **Topology source:** %s\n' "$([[ $HAVE_MAESTRO -eq 1 ]] && echo '`maestro tp`' || echo 'om only')"
    printf -- '- **Update rules:** %s\n\n' "$([[ $HAVE_PYYAML -eq 1 ]] && echo '`bosh manifest` (per-IG max_in_flight/canaries)' || echo 'global fallback')"

    printf '## Summary\n\n'
    printf '| Metric | Value |\n|---|---|\n'
    printf '| Expiring certs (%s) | %d (❌ %d · ⚠️ %d) |\n' "$HORIZON_TEXT" "$((N_LEAF+N_CA))" "$N_CRIT" "$N_WARN"
    printf '| — leaf / CA | %d / %d |\n' "$N_LEAF" "$N_CA"
    printf '| Live VMs (DB nodes) | %d (%d) |\n' "$TOTAL_VMS" "$TOTAL_DB_VMS"
    printf '| One foundation-wide Apply | %s – %s |\n' "$(fmt_min "$FND_LO")" "$(fmt_min "$FND_HI")"
    printf '| **Estimated rotation time** | **%s – %s** |\n' "$(fmt_min "$TOTAL_LO")" "$(fmt_min "$TOTAL_HI")"
    [[ "$DEFER_CA_REMOVAL" == "1" && $(awk -v x="${defer_hi:-0}" 'BEGIN{print (x>0)}') -eq 1 ]] && \
      printf '| Deferred old-CA removal (later) | %s – %s |\n' "$(fmt_min "$defer_lo")" "$(fmt_min "$defer_hi")"
    printf '\n'

    printf '## Foundation inventory\n\n'
    # Per-deployment rotation time = (foundation-wide applies that recreate it) x
    # one-apply cost over its VMs. Falls back to the leaf apply if there are no CAs.
    if [[ ${imm_fnd:-0} -gt 0 ]]; then dep_applies=$imm_fnd
    elif [[ $N_LEAF -gt 0 ]]; then dep_applies=$LEAF_APPLY_COUNT; else dep_applies=0; fi
    printf '| Deployment | Type | VMs | Est. cert-rotation time |\n|---|---|---:|---|\n'
    for dep in "${DEPS[@]}"; do
      if [[ $dep_applies -gt 0 ]]; then
        dlo="$(napply "$dep_applies" "$(scope_minutes low  "$dep")")"
        dhi="$(napply "$dep_applies" "$(scope_minutes high "$dep")")"
        dtime="$(fmt_min "$dlo") – $(fmt_min "$dhi")"
      else dtime="—"; fi
      printf '| `%s` | %s | %d | %s |\n' "$(md_esc "$dep")" "${PROD_TYPE[$dep]:-?}" "${VM_BY_DEP[$dep]:-0}" "$dtime"
    done
    [[ ${N_PARALLEL_IG:-0} -gt 0 ]] && printf '\n> %d instance group(s) have `serial:false` — they may update in parallel, so real time can come in under the (conservative serial) estimate.\n' "$N_PARALLEL_IG"
    printf '\n'

    if [[ ${#CA_MODEL[@]} -gt 0 ]]; then
      # Raw HTML table with a colgroup so the certificate name gets most of the
      # width and the fixed-width expiry stays on one line (styled by the shared CSS).
      printf '## CA rotations (3-phase)\n\n'
      printf '<table>\n<colgroup><col style="width:82%%"><col style="width:18%%"></colgroup>\n'
      printf '<thead><tr><th>Certificate</th><th>Expires</th></tr></thead>\n<tbody>\n'
      for i in "${!CA_MODEL[@]}"; do
        printf '<tr><td><code>%s</code></td><td style="white-space:nowrap">%s</td></tr>\n' \
          "${CA_LABEL[$i]}" "${CA_EXP[$i]}"
      done
      printf '</tbody>\n</table>\n\n'
    fi

    if [[ $N_LEAF -gt 0 ]]; then
      printf '## Leaf certificates\n\n'
      _leafapply="$([[ "${leaf_absorbed:-0}" -eq 1 ]] && echo 'folded into shared apply #2' || echo '1× (leaf campaign)')"
      printf '| Deployment | Leaf certs | Apply |\n|---|---:|---|\n'
      for dep in "${!LEAF_BY_DEP[@]}"; do
        printf '| `%s` | %d | %s |\n' "$(md_esc "$dep")" "${LEAF_BY_DEP[$dep]}" "$_leafapply"
      done
      printf '\n'
    fi

    printf '## Estimate breakdown\n\n'
    printf '| Campaign | Applies | Time (low – high) |\n|---|---|---|\n'
    if [[ $N_LEAF -gt 0 ]]; then
      if [[ "${leaf_absorbed:-0}" -eq 1 ]]; then
        printf '| Leaf certs | folded into the shared apply #2 | included |\n'
      else
        printf '| Leaf certs | %d× over %d deployment(s) | %s – %s |\n' \
          "$LEAF_APPLY_COUNT" "${#LEAF_BY_DEP[@]}" "$(fmt_min "$leaf_lo")" "$(fmt_min "$leaf_hi")"
      fi
    fi
    if [[ ${#CA_MODEL[@]} -gt 0 ]]; then
      case "$CA_BATCH" in
        0) printf '| CA certs (un-batched) | each CA costed separately | %s – %s |\n' "$(fmt_min "$ca_lo")" "$(fmt_min "$ca_hi")";;
        2) if [[ "${leaf_absorbed:-0}" -eq 1 ]]; then
             printf '| CA certs (full batch) | %d× foundation-wide on all tiles — all CAs + leaves | %s – %s |\n' \
               "$max_fnd_phases" "$(fmt_min "$ca_lo")" "$(fmt_min "$ca_hi")"
           else
             printf '| CA certs (batched) | %d× foundation-wide + per-deployment | %s – %s |\n' \
               "$max_fnd_phases" "$(fmt_min "$ca_lo")" "$(fmt_min "$ca_hi")"
           fi;;
        *) printf '| CA certs (batched) | %d× foundation-wide + per-deployment leaf-regen | %s – %s |\n' \
             "$max_fnd_phases" "$(fmt_min "$ca_lo")" "$(fmt_min "$ca_hi")";;
      esac
    fi
    printf '| **Total** | | **%s – %s** |\n\n' "$(fmt_min "$TOTAL_LO")" "$(fmt_min "$TOTAL_HI")"

    printf '## Model & assumptions\n\n'
    printf -- '- %dm overhead per Apply Changes; stateless %d–%dm/VM, DB %d–%dm/node.\n' \
      "$APPLY_OVERHEAD_MIN" "$MIN_PER_VM_LOW" "$MIN_PER_VM_HIGH" "$MIN_PER_VM_DB_LOW" "$MIN_PER_VM_DB_HIGH"
    [[ ${#OV_PAT[@]} -gt 0 ]] && printf -- '- Manual per-IG overrides active: `%s`.\n' "$(md_esc "$IG_RATE_OVERRIDES")"
    printf -- '- A FOUNDATION CA = %d foundation-wide applies; a services TLS CA = %d foundation + %d deployment applies; a deployment CA = %d on its deployment.\n' \
      "$CA_APPLY_COUNT" "$SERVICES_CA_FND_APPLIES" "$SERVICES_CA_DEP_APPLIES" "$DEP_CA_APPLIES"
    printf -- '- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.\n'
  } >&3
fi

# Exit status mirrors the health check: 0 clean, 1 warnings, 2 criticals.
[[ $N_CRIT -gt 0 ]] && exit 2
[[ $N_WARN -gt 0 ]] && exit 1
exit 0
