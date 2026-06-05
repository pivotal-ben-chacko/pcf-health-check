#!/usr/bin/env bash
#
# pcf-health-check.sh — Pre-upgrade health check for a TAS/PCF foundation.
#
# Run this ON the Operations Manager VM (it needs the bosh, cf and om CLIs and
# the credentials exported by env.sh):
#
#     ssh ubuntu@<opsman-ip>
#     ./pcf-health-check.sh                 # sources ~/env.sh automatically
#     ./pcf-health-check.sh --json          # machine-readable summary for CI gates
#     ./pcf-health-check.sh --no-color      # plain text (logs)
#
# What it checks (the goal is to confirm the foundation is healthy BEFORE a
# standard TAS/PCF upgrade):
#   1. BOSH director reachability, stuck locks, in-flight tasks, and the director
#      VM itself (disk/memory/monit processes, reached with the bbr key)
#   2. Every VM's BOSH process state across all deployments (failing jobs,
#      unresponsive agents)
#   3. VM resource utilization — memory, disk (ephemeral/persistent/system),
#      swap and CPU — against pre-upgrade thresholds
#   4. Allocated (provisioned) vs. utilized resources per VM, joining each VM's
#      vm_type from the cloud-config to its live vitals
#   5. Diego cells: VM capacity, BBS container reservations (cfdot cell-states),
#      rolling-upgrade headroom, and app-instance health (cfdot actual-lrps)
#   6. CF API reachability and a quick app/org/space sanity check
#   7. Upgrade readiness: Ops Manager pending changes, stemcell consistency,
#      orphaned disks
#   8. Certificate expiry (Ops Manager) — a top cause of upgrade failures
#   9. MySQL/Galera cluster health via mysql-diag — only when a dedicated
#      mysql_monitor VM exists (full foundation); skipped in small-footprint
#
# Exit status: 0 = healthy, 1 = warnings only, 2 = critical problems found.
#
# It is strictly READ-ONLY. It never modifies the foundation.

set -uo pipefail

# ---------------------------------------------------------------------------
# Tunable thresholds (percent). WARN = look into it, CRIT = block the upgrade.
# ---------------------------------------------------------------------------
MEM_WARN=${MEM_WARN:-85};   MEM_CRIT=${MEM_CRIT:-95}
DISK_WARN=${DISK_WARN:-80}; DISK_CRIT=${DISK_CRIT:-90}
SWAP_WARN=${SWAP_WARN:-20}; SWAP_CRIT=${SWAP_CRIT:-50}
CPU_WARN=${CPU_WARN:-80};   CPU_CRIT=${CPU_CRIT:-95}

# Certificate expiry windows (Ops Manager 'expires_within' syntax: 1w/1m/1y).
CERT_WARN_WINDOW=${CERT_WARN_WINDOW:-1m}; CERT_CRIT_WINDOW=${CERT_CRIT_WINDOW:-1w}

# Health score (1-100): weighted pass ratio over every OK/WARN/CRIT check, then
# capped by severity so the number can never contradict the verdict. A WARN earns
# partial credit; a CRIT earns none. Any CRIT caps the score at SCORE_CRIT_CAP,
# any WARN at SCORE_WARN_CAP. Bands: >=85 healthy, 60-84 caution, <60 not ready.
SCORE_WARN_WEIGHT=${SCORE_WARN_WEIGHT:-0.5}
SCORE_CRIT_CAP=${SCORE_CRIT_CAP:-59}; SCORE_WARN_CAP=${SCORE_WARN_CAP:-84}

# Instance-group name prefixes that are Diego cells (small-footprint = "compute",
# full install = "diego_cell" / "isolated_diego_cell*").
DIEGO_CELL_GROUPS_RE='^(compute|diego_cell|isolated_diego_cell)'

# Errand instance groups (BOSH lifecycle 'errand') are one-off jobs, not
# long-running VMs. In a full/production foundation they appear in `bosh
# instances` — typically not 'running' and often with no active VM — so the
# per-VM checks would flag them as unhealthy/under-utilized, producing false
# positives that drag the health score down. They are detected per-deployment
# from the manifest and skipped by sections 2-5 and the section-7 ignore check.
# EXTRA_EXCLUDE_GROUPS force-excludes additional instance groups by name
# (space/comma-separated), regardless of lifecycle.
EXTRA_EXCLUDE_GROUPS="${EXTRA_EXCLUDE_GROUPS:-}"

# ---------------------------------------------------------------------------
# Presentation helpers
# ---------------------------------------------------------------------------
NO_COLOR=0; JSON_MODE=0; MD_MODE=0
# Foundation name shown in the report title: "PCF <name> Foundation Health Check".
# Set via --foundation <name> / --foundation=<name> or the FOUNDATION_NAME env var
# (e.g. FOG, NDC, PROD). Defaults to "/ TAS" to preserve the original title.
FOUNDATION_NAME="${FOUNDATION_NAME:-/ TAS}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-color) NO_COLOR=1;;
    --json) JSON_MODE=1; NO_COLOR=1;;
    --markdown|--md) MD_MODE=1; NO_COLOR=1;;
    --foundation) shift; FOUNDATION_NAME="${1:-$FOUNDATION_NAME}";;
    --foundation=*) FOUNDATION_NAME="${1#*=}";;
  esac
  shift
done
REPORT_TITLE="PCF ${FOUNDATION_NAME} Foundation Health Check"
if [[ -t 1 && $NO_COLOR -eq 0 ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; BOLD=$'\e[1m'; RST=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; BOLD=""; RST=""
fi

# In --json / --markdown mode, send all human output to /dev/null and keep the
# original stdout on fd 3 for the final document. Every printf/log below stays
# unchanged; only the structured report reaches the caller.
if [[ $JSON_MODE -eq 1 || $MD_MODE -eq 1 ]]; then exec 3>&1 1>/dev/null; fi

WARN_COUNT=0; CRIT_COUNT=0; OK_COUNT=0; CUR_SECTION="general"; FINDINGS=""
# Markdown table buffers (accumulated during the run, rendered at the end).
MD_VITALS=""; MD_ALLOC=""; MD_CELLS=""; LRP_SUMMARY=""
badge(){ case "$1" in OK) printf '✅';; WARN) printf '⚠️';; CRIT) printf '❌';; *) printf 'ℹ️';; esac; }
# Accumulate one finding per OK/WARN/CRIT check for the JSON/Markdown report (TSV rows).
add_finding(){ FINDINGS+="${1}"$'\t'"${CUR_SECTION}"$'\t'"${2}"$'\n'; }
section(){ CUR_SECTION="$(sed -E 's/^[0-9.]+ +//' <<<"$1")"; printf '\n%s%s== %s ==%s\n' "$BOLD" "$B" "$1" "$RST"; }
ok(){    printf '  %s[ OK ]%s %s\n'   "$G" "$RST" "$1"; OK_COUNT=$((OK_COUNT+1)); add_finding OK "$1"; }
info(){  printf '  %s[INFO]%s %s\n'   "$B" "$RST" "$1"; }
warn(){  printf '  %s[WARN]%s %s\n'   "$Y" "$RST" "$1"; WARN_COUNT=$((WARN_COUNT+1)); add_finding WARN "$1"; }
crit(){  printf '  %s[CRIT]%s %s\n'   "$R" "$RST" "$1"; CRIT_COUNT=$((CRIT_COUNT+1)); add_finding CRIT "$1"; }
die(){   printf '\n%s[FATAL]%s %s\n'  "$R" "$RST" "$1" >&2; exit 2; }

# Classify a percentage against warn/crit thresholds; echoes OK|WARN|CRIT.
classify(){ # value warn crit
  local v=$1 w=$2 c=$3
  awk -v v="$v" -v w="$w" -v c="$c" 'BEGIN{ if(v+0>=c) print "CRIT"; else if(v+0>=w) print "WARN"; else print "OK" }'
}
# Emit via the matching log function.
report(){ # level message
  case "$1" in CRIT) crit "$2";; WARN) warn "$2";; *) ok "$2";; esac
}

# Authoritative process state from monit on a specific instance (passwordless sudo
# works for bosh-ssh users on deployment VMs). Echoes the cleaned 'monit summary'
# output, or nothing if the VM/agent is unreachable. BOSH's `instances --ps` leaves
# the state blank for e.g. 'not monitored' processes, which monit reports correctly.
monit_raw(){ # deployment instance
  timeout 90 bosh -d "$1" ssh "$2" -c 'sudo /var/vcap/bosh/bin/monit summary' 2>/dev/null \
    | sed -e 's/\r$//' -e 's/^[^|]*stdout | //'
}

# "15% (614 MB)" -> 15   ;   "" -> -1 (n/a)
pct(){ local s="${1%%\%*}"; [[ -z "$s" || "$s" == "-" ]] && { echo -1; return; }; echo "${s// /}"; }
# "15% (3.0 GB)" -> 3072  (MB, rounded). Returns empty if no absolute part.
paren_to_mb(){
  local inner; inner="$(sed -n 's/.*(\(.*\)).*/\1/p' <<<"$1")"
  [[ -z "$inner" || "$inner" == *i% ]] && { echo ""; return; }   # disk shows inodes, not bytes
  awk -v s="$inner" 'BEGIN{ n=s; sub(/ .*/,"",n); u=s; sub(/^[^ ]* /,"",u);
    if(u=="kB"||u=="KB") n=n/1024; else if(u=="GB") n=n*1024;
    else if(u=="TB") n=n*1024*1024; else if(u=="B") n=n/1048576;
    printf "%.0f", n }'
}
mb_h(){ awk -v m="$1" 'BEGIN{ if(m=="") {print "?"; exit}; if(m>=1024) printf "%.1f GB", m/1024; else printf "%d MB", m }'; }

# ---------------------------------------------------------------------------
# Environment bootstrap — make sure bosh/cf/om are authenticated.
# ---------------------------------------------------------------------------
if [[ -z "${BOSH_ENVIRONMENT:-}" ]]; then
  for f in "$(dirname "$0")/env.sh" "$HOME/env.sh" "./env.sh"; do
    [[ -f "$f" ]] && { info "Sourcing $f"; source "$f" >/dev/null 2>&1; break; }
  done
fi
[[ -z "${BOSH_ENVIRONMENT:-}" ]] && die "BOSH_ENVIRONMENT not set and env.sh not found — cannot reach the director."
command -v bosh >/dev/null || die "bosh CLI not found on PATH."
command -v jq   >/dev/null || die "jq not found on PATH."

printf '%s%s%s%s\n' "$BOLD" "$B" "$REPORT_TITLE" "$RST"
printf 'Director : %s\n' "${BOSH_ENVIRONMENT}"
printf 'Run as   : %s@%s   %s\n' "$(whoami)" "$(hostname)" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# ===========================================================================
# 1. BOSH DIRECTOR HEALTH
# ===========================================================================
section "1. BOSH Director"
if env_json="$(bosh --json env 2>/dev/null)"; then
  # Dedicated names — these must survive until the markdown header is rendered, so
  # they deliberately avoid the generic dver/sver reused by later loops.
  IFS=$'\t' read -r DIR_NAME DIR_VER DIR_CPI < <(jq -r '.Tables[0].Rows[0] | [.name,.version,.cpi] | @tsv' <<<"$env_json")
  ok "Director reachable: ${DIR_NAME} (v${DIR_VER}, ${DIR_CPI})"
else
  die "Cannot reach BOSH director at ${BOSH_ENVIRONMENT} — aborting."
fi

locks="$(bosh --json locks 2>/dev/null | jq -r '.Tables[0].Rows | length')"
if [[ "${locks:-0}" -gt 0 ]]; then
  crit "${locks} active deployment lock(s) — a deploy/operation is in progress; do not upgrade now."
  bosh --json locks 2>/dev/null | jq -r '.Tables[0].Rows[] | "        - \(.type) \(.resource)"'
else
  ok "No active deployment locks."
fi

running_tasks="$(bosh --json tasks 2>/dev/null | jq -r '.Tables[0].Rows | length')"
if [[ "${running_tasks:-0}" -gt 0 ]]; then
  warn "${running_tasks} BOSH task(s) currently running — foundation is mid-operation."
else
  ok "No in-flight BOSH tasks."
fi

# Recently errored tasks are a soft signal worth surfacing.
err_tasks="$(bosh --json tasks --recent=25 2>/dev/null | jq -r '[.Tables[0].Rows[] | select(.state=="error")] | length')"
[[ "${err_tasks:-0}" -gt 0 ]] && warn "${err_tasks} of the last 25 BOSH tasks ended in 'error' (review with: bosh tasks --recent=25)."

# --- Director VM health -----------------------------------------------------
# The director VM is deployed by Ops Manager, not by `bosh`, so it never appears
# in the deployment VM/vitals checks below. Reach it directly over SSH with the
# bbr key (passwordless sudo -> monit). A full director disk (esp. /var/vcap/store,
# which holds the bosh blobstore + postgres) is a classic upgrade blocker.
DIRECTOR_IP="${DIRECTOR_IP:-$BOSH_ENVIRONMENT}"
DIRECTOR_USER="${DIRECTOR_USER:-bbr}"
DIRECTOR_KEY="${DIRECTOR_KEY:-$HOME/bbr.key}"
[[ ! -f "$DIRECTOR_KEY" && -f "$(dirname "$0")/bbr.key" ]] && DIRECTOR_KEY="$(dirname "$0")/bbr.key"
if [[ ! -f "$DIRECTOR_KEY" ]]; then
  info "Director VM: no SSH key at ${DIRECTOR_KEY} — skipping director-VM disk/process check (set DIRECTOR_KEY=...)."
else
  dvm="$(ssh -i "$DIRECTOR_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes \
        "${DIRECTOR_USER}@${DIRECTOR_IP}" '
          echo @@DF;    df -P /var/vcap/store /var/vcap/data / 2>/dev/null | tail -n +2
          echo @@MEM;   free -m | awk "NR==2{print \$2, \$3}"
          echo @@LOAD;  cut -d" " -f1 /proc/loadavg
          echo @@CPU;   nproc
          echo @@MONIT; sudo -n monit summary 2>/dev/null | grep -E "^(Process|System) "
        ' 2>/dev/null)"
  dvm_sect(){ awk -v m="^@@$1\$" '$0 ~ m {f=1;next} /^@@/{f=0} f' <<<"$dvm"; }
  if [[ -z "$dvm" ]]; then
    warn "Director VM ${DIRECTOR_IP}: SSH as ${DIRECTOR_USER} with ${DIRECTOR_KEY##*/} failed — skipping director-VM check."
  else
    info "Director VM ${DIRECTOR_IP} (via ${DIRECTOR_USER}@ ${DIRECTOR_KEY##*/}):"
    # Disk per mount.
    while read -r _fs _size _used _avail pct mount; do
      [[ "$mount" == /* ]] || continue
      c=$(classify "${pct%\%}" $DISK_WARN $DISK_CRIT)
      [[ $c == OK ]] && ok "  disk ${mount}: ${pct} used" || report "$c" "Director VM disk ${mount} at ${pct} used."
    done < <(dvm_sect DF)
    # Memory.
    read -r dmem_total dmem_used < <(dvm_sect MEM)
    if [[ -n "${dmem_total:-}" && "${dmem_total:-0}" -gt 0 ]]; then
      mpct=$(awk -v u="$dmem_used" -v t="$dmem_total" 'BEGIN{printf "%.0f", u*100/t}')
      c=$(classify "$mpct" $MEM_WARN $MEM_CRIT)
      [[ $c == OK ]] && ok "  memory: ${mpct}% (${dmem_used}/${dmem_total} MB)" || report "$c" "Director VM memory at ${mpct}% (${dmem_used}/${dmem_total} MB)."
    fi
    # Load vs vCPU.
    dload="$(dvm_sect LOAD)"; dcpu="$(dvm_sect CPU)"
    [[ -n "$dload" && -n "$dcpu" ]] && info "  load(1m): ${dload} over ${dcpu} vCPU"
    # Monit process states.
    dproc_total=0; dproc_bad=0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      dproc_total=$((dproc_total+1))
      state="$(sed -E "s/^[A-Za-z]+ '[^']+' +//" <<<"$line")"
      if [[ "$state" != "running" && "$state" != "accessible" ]]; then
        dproc_bad=$((dproc_bad+1))
        crit "Director process not healthy: $(sed -E "s/^[A-Za-z]+ '([^']+)'.*/\1/" <<<"$line") -> ${state}"
      fi
    done < <(dvm_sect MONIT)
    [[ $dproc_total -gt 0 && $dproc_bad -eq 0 ]] && ok "  monit: all ${dproc_total} director processes running"
  fi
fi

# ===========================================================================
# Gather deployments
# ===========================================================================
mapfile -t DEPLOYMENTS < <(bosh --json deployments 2>/dev/null | jq -r '.Tables[0].Rows[].name')
[[ ${#DEPLOYMENTS[@]} -eq 0 ]] && die "No BOSH deployments found."
info "Deployments: ${DEPLOYMENTS[*]}"

# Stemcell(s) actually in use per deployment, from `bosh vms` (the per-VM view is
# authoritative — it surfaces a mid-rolling-upgrade split that the deployment-level
# column would hide). Distinct stemcells per deployment, comma-joined. Consumed by
# the stemcell check (section 7) and the final summary.
STEMCELLS_BY_DEP=""
for d in "${DEPLOYMENTS[@]}"; do
  stms="$(bosh -d "$d" --json vms 2>/dev/null \
           | jq -r '.Tables[0].Rows[].stemcell' 2>/dev/null \
           | sed '/^$/d' | sort -u | paste -sd ', ' -)"
  STEMCELLS_BY_DEP+="${d}"$'\t'"${stms:-none}"$'\n'
done

# Errand instance groups per deployment (lifecycle: errand in the manifest), plus
# any names forced via EXTRA_EXCLUDE_GROUPS. The per-VM checks skip these so a
# one-off errand instance never registers as a false failure or pulls the score
# down. is_errand_ig <dep> <ig> is the membership test used throughout.
declare -A ERRAND_BY_DEP
_extra_excl="$(tr ', ' '\n\n' <<<"$EXTRA_EXCLUDE_GROUPS" | sed '/^$/d')"
excl_note=""
for d in "${DEPLOYMENTS[@]}"; do
  igs="$(bosh -d "$d" manifest 2>/dev/null | awk '
      /^instance_groups:/{f=1; next}
      f && /^[A-Za-z]/{f=0}
      f && /^- *name:/{n=$3; next}
      f && /^[[:space:]]+lifecycle:[[:space:]]*errand([[:space:]]|$)/{print n}')"
  igs="$(printf '%s\n%s\n' "$igs" "$_extra_excl" | sed '/^$/d' | sort -u)"
  ERRAND_BY_DEP["$d"]="$igs"
  [[ -n "$igs" ]] && excl_note+="${d}: $(paste -sd ', ' <<<"$igs"); "
done
if [[ -n "$excl_note" ]]; then
  info "Excluding errand/non-VM instance groups from per-VM checks — ${excl_note%; }"
else
  info "No errand instance groups detected — all instance groups are long-running."
fi

# True when instance group $2 in deployment $1 is an errand (skip it in VM checks).
is_errand_ig(){ local l="${ERRAND_BY_DEP[$1]:-}"; [[ -n "$l" ]] && grep -qxF "$2" <<<"$l"; }

# Load vm_type -> cpu/ram(MB)/disk(MB) map from the cloud-config (allocated capacity).
declare -A VT_CPU VT_RAM VT_DISK
while IFS=$'\t' read -r name cpu ram disk; do
  [[ -z "$name" ]] && continue
  VT_CPU["$name"]=$cpu; VT_RAM["$name"]=$ram; VT_DISK["$name"]=$disk
done < <(bosh cloud-config 2>/dev/null | awk '
  /^vm_types:/{inv=1; next}
  inv && /^[A-Za-z]/{inv=0}
  inv && /^- /{cpu="";ram="";disk=""}
  inv && /cpu:/{cpu=$2}
  inv && /ram:/{ram=$2}
  inv && /disk:/{disk=$2}
  inv && /name:/{print $2"\t"cpu"\t"ram"\t"disk}')

# ===========================================================================
# 2. VM PROCESS HEALTH  (per deployment)
# ===========================================================================
section "2. VM & Process Health"
for d in "${DEPLOYMENTS[@]}"; do
  rows="$(bosh --json -d "$d" instances --ps 2>/dev/null \
            | jq -c --arg err "${ERRAND_BY_DEP[$d]:-}" '
                ($err | split("\n") | map(select(length>0))) as $E
                | .Tables[0].Rows[]
                | select( (.instance | split("/")[0]) as $ig | ($E | index($ig) | not) )')"
  [[ -z "$rows" ]] && { warn "[$d] could not list instances."; continue; }

  # VM-level rows have an instance id + ips; process rows carry the process name.
  bad_vms="$(jq -rs '[.[] | select(.process=="-" or .process=="") | select(.process_state!="running")]
                     | .[] | "\(.instance)\t\(.process_state)"' <<<"$rows")"
  bad_procs="$(jq -rs '[.[] | select(.process!="-" and .process!="") | select(.process_state!="running")]
                       | .[] | "\(.instance) \(.process)\t\(.process_state)"' <<<"$rows")"
  total_vms="$(jq -rs '[.[] | select(.process=="-" or .process=="")] | length' <<<"$rows")"

  if [[ -z "$bad_vms" && -z "$bad_procs" ]]; then
    ok "[$d] all ${total_vms} VM(s) and their processes are running."
  else
    # VM-level health first.
    while IFS=$'\t' read -r inst state; do
      [[ -n "$inst" ]] && crit "[$d] VM is unhealthy: ${inst} -> ${state:-unknown}"
    done <<<"$bad_vms"

    # For every affected VM, ask monit for the authoritative per-process state.
    affected="$( { cut -f1 <<<"$bad_vms"; sed -E 's/ .*//' <<<"$bad_procs"; } | sed '/^$/d' | sort -u )"
    while read -r inst; do
      [[ -z "$inst" ]] && continue
      raw="$(monit_raw "$d" "$inst")"
      if grep -q 'Monit daemon' <<<"$raw"; then
        bad="$(awk -F"'" '/^Process /{st=$3; sub(/^[[:space:]]+/,"",st); if(st!="running") print $2"\t"st}' <<<"$raw")"
        if [[ -n "$bad" ]]; then
          while IFS=$'\t' read -r p st; do
            [[ -n "$p" ]] && crit "[$d] process '${p}' on ${inst} -> ${st} (monit)"
          done <<<"$bad"
        else
          info "[$d] ${inst}: monit reports all processes running (VM-level state may be transient)."
        fi
      else
        # monit unreachable (agent/VM likely down) — fall back to BOSH-reported state.
        warn "[$d] ${inst}: could not reach monit (agent/VM may be down); using BOSH-reported state."
        while IFS=$'\t' read -r ip st; do
          [[ "$ip" == "${inst} "* ]] && crit "[$d] process down: ${ip} -> ${st:-unknown}"
        done <<<"$bad_procs"
      fi
    done <<<"$affected"
  fi
done

# ===========================================================================
# 3. VM RESOURCE UTILIZATION  (vitals vs thresholds)
# ===========================================================================
section "3. VM Resource Utilization"
printf '  %-26s %-12s %6s %6s %6s %6s %6s   %s\n' "INSTANCE" "VM_TYPE" "CPU%" "MEM%" "EPH%" "PER%" "SYS%" "LOAD(1m)"
# Classify one metric: emit WARN/CRIT on a breach and raise the VM's worst level.
# Reads $d/$ig and updates $vm_worst from the caller's loop scope. No-op when n/a.
_vm_chk(){ local v=$1 w=$2 cc=$3 lbl=$4 c
  [[ "$v" == "-1" ]] && return
  c=$(classify "$v" "$w" "$cc"); [[ $c == OK ]] && return
  report "$c" "[$d] ${ig} ${lbl} ${v}%"
  if [[ $c == CRIT ]]; then vm_worst=CRIT; elif [[ $vm_worst != CRIT ]]; then vm_worst=WARN; fi
}
for d in "${DEPLOYMENTS[@]}"; do
  while IFS=$'\t' read -r inst vmtype state mem eph per sys cu cs cw load; do
    [[ -z "$inst" ]] && continue
    ig="${inst%%/*}"; is_errand_ig "$d" "$ig" && continue
    short="${ig}/${inst##*/}"; short="${short:0:26}"
    cpu="$(awk -v a="${cu%\%}" -v b="${cs%\%}" -v c="${cw%\%}" 'BEGIN{printf "%.0f",a+b+c}')"
    mp=$(pct "$mem"); ep=$(pct "$eph"); pp=$(pct "$per"); sp=$(pct "$sys")
    l1="${load%%,*}"; gid="${inst##*/}"
    printf '  %-26s %-12s %5s%% %5s%% %5s%% %5s%% %5s%%   %s\n' \
      "$short" "$vmtype" "$cpu" "${mp/-1/  -}" "${ep/-1/  -}" "${pp/-1/  -}" "${sp/-1/  -}" "$l1"
    MD_VITALS+="| ${ig}/${gid:0:8} | ${vmtype} | ${cpu} | ${mp/-1/–} | ${ep/-1/–} | ${pp/-1/–} | ${sp/-1/–} | ${l1} |"$'\n'

    # Threshold checks (skip n/a fields). Any breach emits WARN/CRIT; a VM that is
    # clean across every available metric emits one summarizing OK.
    vm_worst=OK
    _vm_chk "$mp"  $MEM_WARN  $MEM_CRIT  "memory"
    _vm_chk "$ep"  $DISK_WARN $DISK_CRIT "ephemeral disk"
    _vm_chk "$pp"  $DISK_WARN $DISK_CRIT "persistent disk"
    _vm_chk "$sp"  $DISK_WARN $DISK_CRIT "system disk"
    _vm_chk "$cpu" $CPU_WARN  $CPU_CRIT  "CPU"
    [[ $vm_worst == OK ]] && ok "[$d] ${ig} within thresholds (cpu ${cpu}% mem ${mp/-1/–}% eph ${ep/-1/–}% per ${pp/-1/–}% sys ${sp/-1/–}%)"
  done < <(bosh --json -d "$d" vms --vitals 2>/dev/null | jq -r '.Tables[0].Rows[] |
      [.instance, .vm_type, .process_state, .memory_usage, .ephemeral_disk_usage,
       .persistent_disk_usage, .system_disk_usage, .cpu_user, .cpu_sys, .cpu_wait,
       .load_1m_5m_15m] | map(if .==null or .=="" then "-" else . end) | @tsv')
done
info "Thresholds: mem ${MEM_WARN}/${MEM_CRIT}%, disk ${DISK_WARN}/${DISK_CRIT}%, cpu ${CPU_WARN}/${CPU_CRIT}%  (WARN/CRIT)"

# ===========================================================================
# 4. ALLOCATED vs UTILIZED  (provisioned vm_type capacity vs live usage)
# ===========================================================================
section "4. Allocated vs Utilized (per VM)"
printf '  %-22s %-12s   %18s   %18s   %10s\n' "INSTANCE" "VM_TYPE" "RAM used/alloc" "EPHEM used/alloc" "RAM ratio"
for d in "${DEPLOYMENTS[@]}"; do
  while IFS=$'\t' read -r inst vmtype mem eph; do
    [[ -z "$inst" ]] && continue
    ig="${inst%%/*}"; is_errand_ig "$d" "$ig" && continue
    short="${ig}/${inst##*/}"; short="${short:0:22}"
    alloc_ram="${VT_RAM[$vmtype]:-}"; alloc_disk="${VT_DISK[$vmtype]:-}"
    used_ram="$(paren_to_mb "$mem")"
    ep=$(pct "$eph"); used_disk=""
    [[ -n "$alloc_disk" && "$ep" != "-1" ]] && used_disk="$(awk -v p="$ep" -v t="$alloc_disk" 'BEGIN{printf "%.0f", p*t/100}')"
    ratio="$(awk -v u="${used_ram:-0}" -v a="${alloc_ram:-0}" 'BEGIN{ if(a>0) printf "%.0f%%", u*100/a; else print "?" }')"
    printf '  %-22s %-12s   %8s / %-7s   %8s / %-7s   %10s\n' \
      "$short" "$vmtype" "$(mb_h "$used_ram")" "$(mb_h "$alloc_ram")" "$(mb_h "$used_disk")" "$(mb_h "$alloc_disk")" "$ratio"
    gid="${inst##*/}"; MD_ALLOC+="| ${ig}/${gid:0:8} | ${vmtype} | $(mb_h "$used_ram") | $(mb_h "$alloc_ram") | $(mb_h "$used_disk") | $(mb_h "$alloc_disk") | ${ratio} |"$'\n'

    # Acceptability verdict: how full is the VM's *provisioned* RAM. A low ratio is
    # over-provisioned (fine to upgrade); a high ratio means it is running near its
    # allocation and should be addressed before adding upgrade churn. Classified
    # against the memory thresholds. Skipped when the vm_type RAM is unknown.
    rnum="$(awk -v u="${used_ram:-0}" -v a="${alloc_ram:-0}" 'BEGIN{ if(a>0) printf "%.0f", u*100/a; else print -1 }')"
    if [[ "$rnum" == "-1" ]]; then
      info "[$d] ${ig}: vm_type '${vmtype}' RAM not in cloud-config — cannot rate allocation."
    else
      report "$(classify "$rnum" $MEM_WARN $MEM_CRIT)" "[$d] ${ig} RAM allocation ${rnum}% used ($(mb_h "$used_ram") of $(mb_h "$alloc_ram"))"
    fi
  done < <(bosh --json -d "$d" vms --vitals 2>/dev/null | jq -r '.Tables[0].Rows[] |
      [.instance, .vm_type, .memory_usage, .ephemeral_disk_usage] | map(if .==null or .=="" then "-" else . end) | @tsv')
done
info "Allocated = vm_type capacity from cloud-config; Utilized = live BOSH vitals. RAM ratio rated vs mem ${MEM_WARN}/${MEM_CRIT}% (WARN/CRIT); a low ratio is over-provisioned and acceptable."

# ===========================================================================
# 5. DIEGO CELLS  (focused capacity view for the app workload)
# ===========================================================================
section "5. Diego Cells"
# --- 5a. VM-level: provisioned capacity vs OS-level utilization -------------
cell_n=0; first_cell_dep=""; first_cell_grp=""
info "VM-level (provisioned capacity vs OS-utilized):"
for d in "${DEPLOYMENTS[@]}"; do
  while IFS=$'\t' read -r inst vmtype mem load; do
    [[ -z "$inst" ]] && continue
    ig="${inst%%/*}"
    is_errand_ig "$d" "$ig" && continue
    [[ "$ig" =~ $DIEGO_CELL_GROUPS_RE ]] || continue
    [[ -z "$first_cell_dep" ]] && { first_cell_dep="$d"; first_cell_grp="$ig"; }
    alloc_ram="${VT_RAM[$vmtype]:-0}"; alloc_cpu="${VT_CPU[$vmtype]:-?}"; alloc_disk="${VT_DISK[$vmtype]:-0}"
    used_ram="$(paren_to_mb "$mem")"; [[ -z "$used_ram" ]] && used_ram=0
    ratio="$(awk -v u="$used_ram" -v a="$alloc_ram" 'BEGIN{ if(a>0) printf "%.0f", u*100/a; else print 0 }')"
    cell_n=$((cell_n+1))
    info "$(printf '  %-22s %s vCPU / %s RAM / %s disk | OS-used %s (%s%%) | load%s' \
      "${ig}/${inst##*/}" "$alloc_cpu" "$(mb_h "$alloc_ram")" "$(mb_h "$alloc_disk")" "$(mb_h "$used_ram")" "$ratio" "${load%%,*}")"
  done < <(bosh --json -d "$d" vms --vitals 2>/dev/null | jq -r '.Tables[0].Rows[] |
      [.instance, .vm_type, .memory_usage, .load_1m_5m_15m] | map(if .==null or .=="" then "-" else . end) | @tsv')
done

if [[ $cell_n -eq 0 ]]; then
  warn "No Diego cell instance groups matched /${DIEGO_CELL_GROUPS_RE}/ — adjust DIEGO_CELL_GROUPS_RE if cells are named differently."
else
  # --- 5b. Container reservations from the Diego BBS (the upgrade-critical view).
  # One `cfdot cell-states` call (run via a login shell so cfdot is on PATH) returns
  # every cell's Total vs Available container capacity. Allocated = Total - Available.
  info ""
  info "Container allocation (Diego BBS via cfdot cell-states):"
  # Fetch cell capacity and app-instance state in a single login-shell SSH.
  raw="$(timeout 150 bosh -d "$first_cell_dep" ssh "${first_cell_grp}/0" \
          -c 'bash -lc "echo @@CS; cfdot cell-states; echo @@LRP; cfdot actual-lrps"' 2>/dev/null \
          | sed -e 's/\r$//' -e 's/^[^|]*stdout | //')"
  cs="$(awk '/^@@CS$/{f=1;next} /^@@LRP$/{f=0} f' <<<"$raw" | grep '^{')"
  lrp="$(awk '/^@@LRP$/{f=1;next} f' <<<"$raw" | grep '^{')"
  if [[ -z "$cs" ]]; then
    warn "Could not retrieve cfdot cell-states (cfdot/BBS unreachable) — using the VM-level view above only."
  else
    printf '  %-12s %16s %12s %14s %7s\n' "CELL" "ALLOC/CAP RAM" "AVAIL RAM" "CONTAINERS" "ALLOC%"
    bbs_n=0; tot_cap=0; tot_avail=0; max_tmem=0
    while IFS=$'\t' read -r cid tmem amem tcon acon; do
      [[ -z "$cid" ]] && continue
      bbs_n=$((bbs_n+1)); alloc=$((tmem-amem))
      apct=$(awk -v a="$alloc" -v t="$tmem" 'BEGIN{ if(t>0) printf "%.0f", a*100/t; else print 0 }')
      tot_cap=$((tot_cap+tmem)); tot_avail=$((tot_avail+amem))
      [[ $tmem -gt $max_tmem ]] && max_tmem=$tmem
      printf '  %-12s %7s / %-6s %12s %7s/%-6s %5s%%\n' \
        "$cid" "$(mb_h "$alloc")" "$(mb_h "$tmem")" "$(mb_h "$amem")" "$((tcon-acon))" "$tcon" "$apct"
      MD_CELLS+="| ${cid} | $(mb_h "$alloc") | $(mb_h "$tmem") | $(mb_h "$amem") | $((tcon-acon))/${tcon} | ${apct}% |"$'\n'
      v=$(classify "$apct" 85 95); [[ $v != OK ]] && report "$v" "cell ${cid} at ${apct}% memory reserved — little room to place more containers."
    done < <(jq -r '[.cell_id[0:8], .TotalResources.MemoryMB, .AvailableResources.MemoryMB,
                     .TotalResources.Containers, .AvailableResources.Containers] | @tsv' <<<"$cs")

    agg=$(awk -v c="$tot_cap" -v a="$tot_avail" 'BEGIN{ if(c>0) printf "%.0f", (c-a)*100/c; else print 0 }')
    info "Cells: ${bbs_n} | cluster RAM reserved/capacity: $(mb_h $((tot_cap-tot_avail))) / $(mb_h "$tot_cap") (${agg}%) | available: $(mb_h "$tot_avail")"

    # Rolling-upgrade headroom: BOSH recreates cells one (batch) at a time; the drained
    # cell's containers must reschedule onto the survivors. Losing the *largest* cell is
    # the worst case, which reduces to: cluster available RAM >= largest cell capacity.
    if [[ $bbs_n -le 1 ]]; then
      warn "Only ${bbs_n} Diego cell — no peer to evacuate to, so apps WILL restart when it is recreated (expected for single-cell/small-footprint; schedule a maintenance window)."
    elif [[ $tot_avail -ge $max_tmem ]]; then
      ok "Available $(mb_h "$tot_avail") >= largest cell $(mb_h "$max_tmem") — a cell can be drained during a rolling upgrade without exhausting placement capacity."
    else
      crit "Available RAM $(mb_h "$tot_avail") < largest cell capacity $(mb_h "$max_tmem") — draining a cell may fail to reschedule its apps. Scale out cells or reduce load before upgrading."
    fi

    # --- 5c. App-instance health from the BBS (cfdot actual-lrps) -----------
    if [[ -n "$lrp" ]]; then
      declare -A LST=()
      while read -r st; do [[ -n "$st" ]] && LST["$st"]=$(( ${LST["$st"]:-0} + 1 )); done \
        < <(jq -r '.state' <<<"$lrp")
      LRP_SUMMARY="$(for k in "${!LST[@]}"; do printf '%s=%s ' "$k" "${LST[$k]}"; done)"
      info "App instances (actual LRPs): ${LRP_SUMMARY}"
      [[ "${LST[CRASHED]:-0}"   -gt 0 ]] && warn "${LST[CRASHED]} app instance(s) CRASHED — investigate before upgrading (a rolling restart will mask, not fix, these)."
      [[ "${LST[UNCLAIMED]:-0}" -gt 0 ]] && crit "${LST[UNCLAIMED]} app instance(s) UNCLAIMED — Diego cannot place them now; an upgrade that drains a cell will make placement worse."
    fi
  fi
fi

# ===========================================================================
# 6. CLOUD FOUNDRY PLATFORM
# ===========================================================================
section "6. Cloud Foundry API"
if command -v cf >/dev/null && cf_t="$(cf target 2>/dev/null)"; then
  api="$(awk -F'   *' '/API endpoint/{print $2}' <<<"$cf_t")"
  apiver="$(awk -F'   *' '/API version/{print $2}' <<<"$cf_t")"
  cuser="$(awk -F'   *' '/^user:/{print $2}' <<<"$cf_t")"
  if [[ -n "$api" && -n "$cuser" ]]; then
    ok "CF API reachable: ${api} (v${apiver}) as ${cuser}"
    orgs="$(cf curl '/v3/organizations?per_page=1' 2>/dev/null | jq -r '.pagination.total_results // empty')"
    apps="$(cf curl '/v3/apps?per_page=1'          2>/dev/null | jq -r '.pagination.total_results // empty')"
    spaces="$(cf curl '/v3/spaces?per_page=1' 2>/dev/null | jq -r '.pagination.total_results // empty')"
    [[ -n "$orgs" ]] && info "Orgs: ${orgs} | Spaces: ${spaces:-?} | Apps: ${apps:-?}"
    # Per-instance app crash state is covered at the Diego layer in section 5
    # (cfdot actual-lrps); use 'cf apps' per org for app-by-app detail.
    info "Per-instance crash state is reported in section 5 (Diego actual-LRPs)."
  else
    warn "CF CLI not logged in (no user/api in 'cf target') — skipping CF checks."
  fi
else
  warn "CF CLI unavailable or not targeted — skipping CF platform checks."
fi

# ===========================================================================
# 7. UPGRADE READINESS  (Ops Manager state + cert/stemcell/disk hygiene)
# ===========================================================================
section "7. Upgrade Readiness"

# Ops Manager pending changes — anything not 'unchanged' is staged but unapplied;
# it should be applied or reverted first, or the upgrade bundles it unexpectedly.
if command -v om >/dev/null; then
  # Pull the product label, identifier, version transition, errand count and guid
  # (the guid is the product's BOSH deployment name) for every staged change.
  pc="$(om curl -s -p /api/v0/staged/pending_changes 2>/dev/null | jq -r '
    .product_changes[]? | [
      .action, .guid,
      (.staged.identifier // .deployed.identifier // "?"),
      (.staged.label      // .deployed.label      // "?"),
      (.deployed.version // ""), (.staged.version // ""),
      ((.errands // []) | length)
    ] | @tsv' 2>/dev/null)"
  if [[ -z "$pc" ]]; then
    info "Could not read Ops Manager pending changes (om not configured?) — skipping."
  else
    pc_changed=0
    while IFS=$'\t' read -r action guid ident label dver sver ecount; do
      [[ -z "$action" || "$action" == "unchanged" ]] && continue
      pc_changed=$((pc_changed+1))
      case "$action" in
        install) vtxt="install v${sver:-?}";;
        update)  vtxt="update v${dver:-?} → v${sver:-?}";;
        delete)  vtxt="DELETE (currently v${dver:-?})";;
        *)       vtxt="$action";;
      esac
      errtxt=""; [[ "${ecount:-0}" -gt 0 ]] && errtxt=" · ${ecount} errand(s) will run"
      warn "Staged change: ${label} [${ident}] — ${vtxt} (deployment '${guid}')${errtxt}. Apply or revert before upgrading."
    done <<<"$pc"
    [[ $pc_changed -eq 0 ]] && ok "No pending Ops Manager changes (all products 'unchanged')."
  fi
else
  info "om CLI not available — skipping pending-changes check."
fi

# Stemcells — flag more than one version of the same OS still uploaded/in use.
sc="$(bosh --json stemcells 2>/dev/null | jq -r '.Tables[0].Rows[]? | "\(.os)\t\(.version)"' 2>/dev/null)"
if [[ -n "$sc" ]]; then
  dupes="$(awk -F'\t' '{c[$1]++} END{for(o in c) if(c[o]>1) printf "%s(%d) ",o,c[o]}' <<<"$sc")"
  if [[ -n "$dupes" ]]; then
    warn "Multiple stemcell versions present for: ${dupes}— tidy with 'bosh clean-up' so the upgrade lands on one line."
  else
    ok "Stemcells consistent: $(awk -F'\t' '{printf "%s/%s ",$1,$2}' <<<"$sc")"
  fi
  # Show which stemcell each deployment is actually running on.
  while IFS=$'\t' read -r dep stm; do
    [[ -z "$dep" ]] && continue
    info "  ${dep}: ${stm:-none}"
  done <<<"$STEMCELLS_BY_DEP"
fi

# Orphaned persistent disks accumulate after failed/edited deploys.
od="$(bosh --json disks --orphaned 2>/dev/null | jq -r '.Tables[0].Rows | length' 2>/dev/null)"
if [[ -n "$od" ]]; then
  [[ "${od:-0}" -gt 0 ]] && warn "${od} orphaned persistent disk(s) — review with 'bosh disks --orphaned' / 'bosh clean-up'." \
                         || ok "No orphaned persistent disks."
fi

# Ignored instances ('bosh ignore') are deliberately skipped by BOSH during a
# deploy, so they will NOT receive the new stemcell/release in an upgrade and can
# fail the Apply Changes. They must be 'bosh unignore'd before upgrading.
ign_total=0
for d in "${DEPLOYMENTS[@]}"; do
  while IFS= read -r inst; do
    [[ -z "$inst" ]] && continue
    is_errand_ig "$d" "${inst%%/*}" && continue
    ign_total=$((ign_total+1))
    crit "[$d] instance set to IGNORE: ${inst} — BOSH will skip it during the upgrade; run 'bosh -d ${d} unignore ${inst}' first."
  done < <(bosh --json -d "$d" instances --details 2>/dev/null \
            | jq -r '.Tables[0].Rows[]? | select(.ignore=="true") | .instance' 2>/dev/null)
done
[[ $ign_total -eq 0 ]] && ok "No ignored instances — every VM will be updated during the upgrade."

# ===========================================================================
# 8. CERTIFICATES  (expiry is a top cause of upgrade failures)
# ===========================================================================
section "8. Certificates"
# This Ops Manager reports expiry only via the 'expires_within' filter (dates are
# null in the full list), so query escalating windows and always show the breakdown.
if command -v om >/dev/null; then
  total="$(om curl -s -p /api/v0/deployed/certificates 2>/dev/null | jq -r '.certificates|length' 2>/dev/null)"
  cc="$(om curl -s -p "/api/v0/deployed/certificates?expires_within=${CERT_CRIT_WINDOW}" 2>/dev/null | jq -r '.certificates|length' 2>/dev/null)"
  cw="$(om curl -s -p "/api/v0/deployed/certificates?expires_within=${CERT_WARN_WINDOW}" 2>/dev/null | jq -r '.certificates|length' 2>/dev/null)"
  cy="$(om curl -s -p "/api/v0/deployed/certificates?expires_within=1y" 2>/dev/null | jq -r '.certificates|length' 2>/dev/null)"
  if [[ -z "$cy" ]]; then
    warn "Could not read certificate expiry from Ops Manager — verify manually before upgrading."
  else
    info "Deployed certificates: ${total:-?} total | expiring ≤${CERT_CRIT_WINDOW}: ${cc:-0} · ≤${CERT_WARN_WINDOW}: ${cw:-0} · ≤1y: ${cy}"
    if [[ "${cc:-0}" -gt 0 ]]; then
      crit "${cc} certificate(s) expire within ${CERT_CRIT_WINDOW} — rotate before upgrading (Ops Manager > Settings > Advanced > Rotate, or 'om regenerate-certificates')."
    elif [[ "${cw:-0}" -gt 0 ]]; then
      warn "${cw} certificate(s) expire within ${CERT_WARN_WINDOW} — plan rotation soon."
    else
      ok "No certificates expiring within ${CERT_WARN_WINDOW}."
    fi
  fi
else
  info "om CLI not available — skipping certificate check."
fi

# ===========================================================================
# 9. MYSQL / GALERA CLUSTER  (only when a dedicated mysql_monitor VM exists)
# ===========================================================================
section "9. MySQL / Galera Cluster"
# mysql-diag runs on the mysql_monitor VM in a full foundation. In small-footprint
# there is no mysql_monitor (MySQL is colocated on 'database'), so this is skipped
# — the DB VM, its Galera/PXC processes, and resources are still covered in 2–4.
mon_dep=""; mon_grp=""
for d in "${DEPLOYMENTS[@]}"; do
  g="$(bosh --json -d "$d" instances 2>/dev/null \
        | jq -r '.Tables[0].Rows[].instance' | sed -E 's#/.*##' | sort -u \
        | grep -E '^mysql[-_]monitor' | head -1)"
  [[ -n "$g" ]] && { mon_dep="$d"; mon_grp="$g"; break; }
done
if [[ -z "$mon_grp" ]]; then
  info "No mysql_monitor VM present (small-footprint) — skipping mysql-diag; MySQL VM/processes/resources covered in sections 2–4."
else
  out="$(timeout 120 bosh -d "$mon_dep" ssh "${mon_grp}/0" \
          -c 'sudo /var/vcap/jobs/mysql-diag/bin/mysql-diag' 2>/dev/null \
          | sed -e 's/\r$//' -e 's/^[^|]*stdout | //')"
  if [[ -z "$out" ]]; then
    warn "mysql-diag on ${mon_grp}/0 returned nothing (no privilege/timeout) — verify cluster health manually before upgrading."
  else
    synced="$(grep -ioc 'synced' <<<"$out")"
    if grep -qiE 'critical|unhealthy|not running|cannot connect|unreachable' <<<"$out"; then
      crit "mysql-diag reports a CRITICAL cluster issue on ${mon_grp} — resolve before upgrading (see detail below)."
    elif grep -qiE 'warning|diverg|behind|read-only' <<<"$out"; then
      warn "mysql-diag reports a warning on ${mon_grp} — review cluster state before upgrading (see detail below)."
    else
      ok "mysql-diag: Galera cluster healthy on ${mon_grp} (${synced} node(s) reported Synced)."
    fi
    # Surface the key status lines so the operator sees mysql-diag's own verdict.
    while IFS= read -r line; do [[ -n "$line" ]] && info "  ${line}"; done \
      < <(grep -iE 'synced|wsrep|canary|healthy|unhealthy|critical|warning|host|node' <<<"$out" | head -20)
  fi
fi

# ===========================================================================
# VERDICT
# ===========================================================================
section "Summary"
printf '  Checks: %s%d%s OK   Warnings: %s%d%s   Critical: %s%d%s\n' \
  "$G" "$OK_COUNT" "$RST" "$Y" "$WARN_COUNT" "$RST" "$R" "$CRIT_COUNT" "$RST"

# Stemcells in use, per deployment.
printf '\n  %sStemcells in use:%s\n' "$BOLD" "$RST"
while IFS=$'\t' read -r dep stm; do
  [[ -z "$dep" ]] && continue
  printf '    %-28s %s\n' "$dep" "${stm:-none}"
done <<<"$STEMCELLS_BY_DEP"

# Health score (1-100): weighted pass ratio, then capped by severity so it can
# never disagree with the verdict (a lone CRIT among many OKs still scores <=cap).
HEALTH_SCORE="$(awk -v ok="$OK_COUNT" -v w="$WARN_COUNT" -v c="$CRIT_COUNT" \
  -v ww="$SCORE_WARN_WEIGHT" -v ccap="$SCORE_CRIT_CAP" -v wcap="$SCORE_WARN_CAP" 'BEGIN{
    total=ok+w+c;
    if(total==0){ print 100; exit }
    s=100*(ok + w*ww)/total;          # CRIT contributes 0
    if(c>0 && s>ccap) s=ccap; else if(w>0 && s>wcap) s=wcap;
    if(s<1) s=1; if(s>100) s=100;
    printf "%.0f", s }')"
if   [[ $HEALTH_SCORE -ge 85 ]]; then scolor="$G"
elif [[ $HEALTH_SCORE -ge 60 ]]; then scolor="$Y"
else scolor="$R"; fi
printf '\n  %sHealth score: %s%s%%%s\n' "$BOLD" "$scolor" "$HEALTH_SCORE" "$RST"

if   [[ $CRIT_COUNT -gt 0 ]]; then
  verdict="NOT_READY"; exit_code=2; vcolor="$R"
  vmsg="NOT READY for upgrade — resolve the ${CRIT_COUNT} critical item(s) above."
elif [[ $WARN_COUNT -gt 0 ]]; then
  verdict="CAUTION"; exit_code=1; vcolor="$Y"
  vmsg="PROCEED WITH CAUTION — ${WARN_COUNT} warning(s); review before upgrading."
else
  verdict="HEALTHY"; exit_code=0; vcolor="$G"
  vmsg="HEALTHY — foundation looks ready for a standard TAS/PCF upgrade."
fi
printf '\n%s%sVERDICT: %s%s\n' "$BOLD" "$vcolor" "$vmsg" "$RST"

# Machine-readable summary for CI/upgrade gates (fd 3 = the real stdout).
if [[ $JSON_MODE -eq 1 ]]; then
  findings_json="$(printf '%s' "$FINDINGS" | jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({level:.[0],section:.[1],message:.[2]})')"
  jq -n --arg v "$verdict" --argjson ec "$exit_code" --argjson w "$WARN_COUNT" \
        --argjson c "$CRIT_COUNT" --argjson ok "$OK_COUNT" --argjson hs "$HEALTH_SCORE" \
        --arg dir "${BOSH_ENVIRONMENT:-}" \
        --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" --argjson f "$findings_json" \
        '{verdict:$v, health_score:$hs, exit_code:$ec, ok:$ok, warnings:$w, criticals:$c,
          director:$dir, generated_at_utc:$ts, findings:$f}' >&3
fi

# Markdown report (fd 3 = the real stdout). Convert to PDF off-box, e.g.:
#   pandoc report.md -o report.html --standalone && chrome --headless --print-to-pdf
if [[ $MD_MODE -eq 1 ]]; then
  case "$verdict" in HEALTHY) vb='✅';; CAUTION) vb='⚠️';; *) vb='❌';; esac
  cnt(){ awk -F'\t' -v s="$1" -v l="$2" '$2==s&&$1==l{n++} END{print n+0}' <<<"$FINDINGS"; }
  md_bullets(){ awk -F'\t' -v s="$1" '$2==s{b=$1=="OK"?"✅":($1=="WARN"?"⚠️":($1=="CRIT"?"❌":"ℹ️")); m=$3; sub(/^ +/,"",m); print "- "b" "m}' <<<"$FINDINGS"; }
  {
    printf '# %s\n\n' "$REPORT_TITLE"
    printf '> **%s Verdict: %s** — %s\n>\n> **Health score: %s%%**\n\n' "$vb" "$verdict" "$vmsg" "$HEALTH_SCORE"
    printf '| | |\n|---|---|\n'
    printf '| **Director** | `%s` — %s v%s (%s) |\n' "${BOSH_ENVIRONMENT:-?}" "${DIR_NAME:-?}" "${DIR_VER:-?}" "${DIR_CPI:-?}"
    printf '| **Generated** | %s |\n' "$(date -u '+%Y-%m-%d %H:%M UTC')"
    printf '| **Run on** | `%s@%s` |\n' "$(whoami)" "$(hostname)"
    printf '| **Deployments** | %s |\n' "${DEPLOYMENTS[*]}"
    # One stemcell per line in the cell (<br> = a line break once pandoc renders it).
    stm_used="$(cut -f2 <<<"$STEMCELLS_BY_DEP" | tr ',' '\n' | sed 's/^ *//;s/ *$//;/^$/d' | sort -u | paste -sd $'\t' - | sed 's/\t/<br>/g')"
    printf '| **Stemcell(s) in use** | %s |\n' "${stm_used:-?}"
    printf '| **Checks (OK / Warn / Crit)** | %s / %s / %s |\n' "$OK_COUNT" "$WARN_COUNT" "$CRIT_COUNT"
    printf '| **Health score** | **%s%%** |\n\n' "$HEALTH_SCORE"

    printf '## Summary by section\n\n'
    printf '| Section | ✅ OK | ⚠️ Warn | ❌ Crit |\n|---|--:|--:|--:|\n'
    for s in "BOSH Director" "VM & Process Health" "VM Resource Utilization" \
             "Allocated vs Utilized (per VM)" "Diego Cells" "Cloud Foundry API" \
             "Upgrade Readiness" "Certificates" "MySQL / Galera Cluster"; do
      printf '| %s | %s | %s | %s |\n' "$s" "$(cnt "$s" OK)" "$(cnt "$s" WARN)" "$(cnt "$s" CRIT)"
    done

    printf '\n## 1. BOSH Director\n\n'; md_bullets "BOSH Director"
    [[ -n "${dproc_total:-}" ]] && printf '\n_Director VM: memory %s%%%s, load %s over %s vCPU, %s monit processes running._\n' \
        "${mpct:-?}" "$([[ -n "${dmem_used:-}" ]] && printf ' (%s/%s MB)' "$dmem_used" "$dmem_total")" "${dload:-?}" "${dcpu:-?}" "${dproc_total}"

    printf '\n## 2. VM & Process Health\n\n'; md_bullets "VM & Process Health"

    printf '\n## 3. VM Resource Utilization\n\n'
    if [[ -n "$MD_VITALS" ]]; then
      printf '| Instance | VM Type | CPU%% | Mem%% | Eph%% | Per%% | Sys%% | Load |\n|---|---|--:|--:|--:|--:|--:|--:|\n'
      printf '%s\n' "$MD_VITALS"
    fi
    md_bullets "VM Resource Utilization"
    printf '\n_Thresholds — mem %s/%s%%, disk %s/%s%%, cpu %s/%s%% (WARN/CRIT)._\n' "$MEM_WARN" "$MEM_CRIT" "$DISK_WARN" "$DISK_CRIT" "$CPU_WARN" "$CPU_CRIT"

    printf '\n## 4. Allocated vs Utilized\n\n'
    if [[ -n "$MD_ALLOC" ]]; then
      printf '| Instance | VM Type | RAM used | RAM alloc | Ephem used | Ephem alloc | RAM ratio |\n|---|---|--:|--:|--:|--:|--:|\n'
      printf '%s\n' "$MD_ALLOC"
    fi
    md_bullets "Allocated vs Utilized (per VM)"

    printf '\n## 5. Diego Cells\n\n'
    [[ -n "${bbs_n:-}" ]] && printf '**Cells:** %s · reserved/capacity %s / %s (%s%%) · available %s · LRPs: %s\n\n' \
        "$bbs_n" "$(mb_h $((tot_cap-tot_avail)))" "$(mb_h "$tot_cap")" "$agg" "$(mb_h "$tot_avail")" "${LRP_SUMMARY:-n/a}"
    if [[ -n "$MD_CELLS" ]]; then
      printf '| Cell | Reserved | Capacity | Available | Containers | Reserved%% |\n|---|--:|--:|--:|--:|--:|\n'
      printf '%s\n' "$MD_CELLS"
    fi
    md_bullets "Diego Cells"

    printf '\n## 6. Cloud Foundry API\n\n'; md_bullets "Cloud Foundry API"
    [[ -n "${orgs:-}" ]] && printf '\n_Orgs: %s · Spaces: %s · Apps: %s._\n' "${orgs}" "${spaces:-?}" "${apps:-?}"

    printf '\n## 7. Upgrade Readiness\n\n'; md_bullets "Upgrade Readiness"
    if [[ -n "$STEMCELLS_BY_DEP" ]]; then
      printf '\n**Stemcells in use:**\n\n| Deployment | Stemcell |\n|---|---|\n'
      while IFS=$'\t' read -r dep stm; do
        [[ -z "$dep" ]] && continue
        printf '| %s | %s |\n' "$dep" "$(sed 's/, /<br>/g' <<<"${stm:-none}")"
      done <<<"$STEMCELLS_BY_DEP"
    fi

    printf '\n## 8. Certificates\n\n'; md_bullets "Certificates"

    printf '\n## 9. MySQL / Galera Cluster\n\n'; md_bullets "MySQL / Galera Cluster"

    printf -- '\n---\n_Generated by pcf-health-check.sh — read-only pre-upgrade health check._\n'
  } >&3
fi
exit $exit_code
