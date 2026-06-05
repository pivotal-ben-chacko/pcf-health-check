# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What's here

- `pcf-health-check.sh` — read-only pre-upgrade health check for a TAS/PCF foundation.
  Designed to run **on the opsman VM**. Exit 0 = healthy, 1 = warnings, 2 = critical.
  Tunable thresholds via env vars at the top; `--no-color` for logs, `--json` for a
  CI-gate summary (findings tagged by section/level; written to stdout, human output
  suppressed). Sections:
  1. BOSH director (reachability, locks, tasks) + the **director VM** itself
     (disk/`/var/vcap/store`, memory, load, monit processes via the bbr key)
  2. Per-VM BOSH process state across all deployments
  3. VM resource utilization (mem/disk/cpu/swap) vs thresholds
  4. Allocated (cloud-config `vm_type`) vs utilized (vitals) per VM
  5. Diego cells: VM capacity, BBS container reservations (`cfdot cell-states`),
     rolling-upgrade headroom, app-instance health (`cfdot actual-lrps`)
  6. CF API reachability + org/space/app counts
  7. Upgrade readiness: `om` pending changes (listed per product with action,
     version transition and deployment guid), stemcell consistency, orphaned
     disks, and ignored instances (`bosh instances --details` Ignore column —
     CRIT, since ignored VMs are skipped during the upgrade). Also lists the
     stemcell(s) in use per deployment, derived from `bosh vms` (per-VM, so a
     mid-rolling-upgrade split shows as two stemcells); the same mapping is
     echoed in the final Summary and the Markdown report.
  8. Certificates: expiry via `om` (dedicated section)
  9. MySQL/Galera cluster health via `mysql-diag` — **only** when a dedicated
     `mysql_monitor` VM exists (full foundation); skipped in small-footprint.
     NOTE: the mysql-diag run/parse path is UNVERIFIED — the lab has no
     `mysql_monitor`, so only detection + skip are tested. Validate and tune
     the output parsing against a real full foundation before relying on it.

Health score: the Summary section (and `--json`/`--markdown` output) reports a
1–100 score = weighted pass ratio over every OK/WARN/CRIT check (WARN earns
`SCORE_WARN_WEIGHT`=0.5 credit, CRIT earns none), then **capped by severity** so
the number can't contradict the verdict — any CRIT caps at `SCORE_CRIT_CAP`=59,
any WARN at `SCORE_WARN_CAP`=84. Bands: ≥85 healthy, 60–84 caution, <60 not
ready. Caps/weight are tunable env vars at the top of the script.

Cert status caveat: this Ops Manager returns expiry only via the
`expires_within` filter (dates are null in the full list), so section 8 reports
counts per window (1w CRIT / 1m WARN / 1y info) plus the total deployed, not
individual cert names.

## Accessing the Operations Manager VM

```sh
ssh ubuntu@192.168.2.85          # NOTE: 192.168.2.80 is vCenter, not opsman
source env.sh                    # authenticates the bosh, cf and om CLIs
```

`env.sh` lives on the opsman VM (not in this repo). It exports `BOSH_CLIENT`/secret
(director at 192.168.2.2), `OM_*` for the `om` CLI, and runs `cf login`. The script
sources it automatically if `BOSH_ENVIRONMENT` is unset.

## Running the health check

```sh
scp pcf-health-check.sh ubuntu@192.168.2.85:~/   # then ssh in
./pcf-health-check.sh            # human output (colored)
./pcf-health-check.sh --no-color # plain text for logs
./pcf-health-check.sh --json     # JSON summary for CI gates (stdout only)
./pcf-health-check.sh --markdown # Markdown report (stdout only)
./pcf-health-check.sh --foundation FOG   # title -> "PCF FOG Foundation Health Check"
```

The report title is `PCF <name> Foundation Health Check`; set `<name>` with
`--foundation <name>` / `--foundation=<name>` or the `FOUNDATION_NAME` env var
(defaults to `/ TAS`, preserving the original title).

## Building a PDF/HTML report (run on the Mac, not opsman)

`./build-report.sh` SSHes to opsman, runs `--markdown`, then renders with the
local toolchain: **pandoc** (Markdown → standalone HTML, CSS from
`report-style.css`, Fiserv-branded; logo injected via `--include-before-body
report-header.html`) → **Chrome headless** (`--print-to-pdf`). Outputs
`health-report.{md,html,pdf}`. Requires pandoc + Google Chrome on the Mac (no
LaTeX needed — Chrome does the PDF). The opsman VM has neither, so PDF rendering
is intentionally done locally. Pass `FOUNDATION=FOG ./build-report.sh` to set the
report title (forwarded to the remote run and the HTML page title).

Branding lives only in the render step (Mac side): `report-style.css` (Fiserv
palette — orange `#FF6600` on charcoal) and `report-header.html` (inline Fiserv
logo SVG, sized via `.brand-logo`). The script itself emits unbranded,
portable Markdown/JSON. Note: the check exits 1/2 on warnings/criticals,
which is expected, not a build failure (the script tolerates it).

## Environment notes

- This test foundation runs **small-footprint TAS** (instance groups: `blobstore`,
  `compute` = Diego cell, `control`, `database`, `router`); the real target is a
  **full install** with dedicated component VMs. The script auto-detects deployments
  and vm_types, and its Diego-cell regex matches both `compute` and `diego_cell*`,
  so it is portable to the full install without edits.
- **Errand instance groups are excluded from the per-VM checks.** A full/prod
  foundation has `lifecycle: errand` instance groups (e.g. `bootstrap`,
  `nfsbrokerpush`, `smoke_tests`) that show up in `bosh instances` as not-running
  with no active VM; checking them produced false positives that dragged the
  health score down. After gathering deployments the script reads each
  deployment's manifest, collects instance groups with `lifecycle: errand`
  (per-deployment, in `ERRAND_BY_DEP`), and `is_errand_ig <dep> <ig>` skips them
  in sections 2–5 and the section-7 ignore check. It logs which groups were
  excluded (or "No errand instance groups detected"). The lab is all
  `lifecycle: service`, so this is a no-op there. `EXTRA_EXCLUDE_GROUPS` (env,
  space/comma list) force-excludes additional groups by name regardless of
  lifecycle. NOTE: errands that are *colocated* on a real instance group (most
  TAS errands) run on a long-running VM and are correctly NOT excluded — only
  standalone `lifecycle: errand` instance groups are.
- Diego container allocation comes from `cfdot cell-states`, run over `bosh ssh`.
  `cfdot` is only on PATH in a **login** shell, so the script invokes it as
  `bosh -d <dep> ssh <cell>/0 -c 'bash -lc "cfdot cell-states"'` (a plain
  `-c "cfdot ..."` non-login shell gives "command not found"; `sudo` is not
  needed). One call returns all cells. Allocated = Total − Available resources.
- The BOSH director VM itself is not in `bosh deployments`; SSH directly with
  `ssh -i bbr.key bbr@192.168.2.2` (key in the opsman home dir) to inspect its
  own disk/`/var/vcap/store` if a director-VM health check is added later.
