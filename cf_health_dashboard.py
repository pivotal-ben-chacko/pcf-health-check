#!/usr/bin/env python3
"""cf_health_dashboard.py — one-page Fiserv "Foundation Health Check" dashboard
from a pcf-health-check.sh markdown report. Single file, no assets.

  python3 cf_health_dashboard.py jca-10-15-2026.md                       # -> jca-health-dashboard-<today>.pdf
  python3 cf_health_dashboard.py jca-10-15-2026.md --products om-products.txt --buildpacks cf-buildpacks.txt
  python3 cf_health_dashboard.py report.md --foundation JCA --author "Ben Chacko" --date "October 15, 2026" \
          --certs-3m 3 -o jca.pdf --png --html

  --products   text file with `om products` output   -> "Deployed tiles" table
  --buildpacks text file with `cf buildpacks` output -> "Buildpacks" table
  --png        also write <out>.png (1600px, for e-mail embedding)
  --html       also keep <out>.html

Dependencies: python3 >= 3.8, matplotlib, numpy, and the wkhtmltopdf binary
(wkhtmltoimage from the same package for --png; Pillow optional, shrinks the PNG).
  Ubuntu/Debian: apt-get install -y python3 python3-matplotlib python3-numpy python3-pil wkhtmltopdf
  pip:           pip install matplotlib numpy pillow   (+ wkhtmltopdf from your distro or wkhtmltopdf.org)
"""
import argparse, base64, io, os, re, shutil, subprocess, sys, tempfile
from datetime import date as _date
from collections import OrderedDict, Counter
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ORANGE, DARK, GREY, LIGHT = "#FB6400", "#333333", "#9B9B9B", "#E6E6E6"
GREEN, AMBER, RED = "#2e7d32", "#e8930c", "#c62828"
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 8.5, "axes.edgecolor": GREY,
                     "axes.spines.top": False, "axes.spines.right": False,
                     "axes.titlesize": 9, "axes.titleweight": "bold", "axes.titlecolor": DARK})

def png(fig):
    buf = io.BytesIO(); fig.savefig(buf, format="png", dpi=160, bbox_inches="tight", transparent=True)
    plt.close(fig); return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

def sections(md):
    out, cur, buf = OrderedDict(), "_head", []
    for line in md.splitlines():
        if line.startswith("## "):
            out[cur] = "\n".join(buf); cur, buf = line[3:].strip(), []
        else: buf.append(line)
    out[cur] = "\n".join(buf); return out

def find(secs, needle):
    for k, v in secs.items():
        if needle.lower() in k.lower(): return v
    return ""

LOGO_URI = "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTYwIiBoZWlnaHQ9IjYwIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxyZWN0IHdpZHRoPSIxNjAiIGhlaWdodD0iNjAiIGZpbGw9IiNGQjY0MDAiLz4KICA8dGV4dCB4PSIxNSIgeT0iNDIiIGZvbnQtZmFtaWx5PSJBcmlhbCwgc2Fucy1zZXJpZiIgZm9udC1zaXplPSIzMiIgZm9udC13ZWlnaHQ9IjMwMCIgZmlsbD0id2hpdGUiPmZpc2Vydi48L3RleHQ+Cjwvc3ZnPg=="

class _KV(dict):
    """Header-table lookup; a row the report lacks reads as "" (with a one-time warning) instead of crashing."""
    def __missing__(self, key):
        print(f"WARNING: header table has no '{key}' row — that panel will show n/a", file=sys.stderr)
        self[key] = ""; return ""

def kv(body):
    return _KV({m.group(1): m.group(2) for m in re.finditer(r"^\| \*\*(.+?)\*\* \| (.+?) \|$", body, re.M)})

def parse_products(txt):
    rows = []
    for line in txt.splitlines():
        m = re.match(r"\|\s*(\S+)\s*\|\s*(\S*)\s*\|\s*(\S*)\s*\|\s*(\S*)\s*\|", line)
        if m and m.group(1) != "NAME" and m.group(4):
            rows.append((m.group(1), m.group(4), m.group(3)))
    return rows

def parse_buildpacks(txt):
    rows = []
    for line in txt.splitlines():
        m = re.match(r"\s*(\d+)\s+(\S+)\s+(\S+)\s+(true|false)\s+(true|false)\s+(\S+)\s+(\S+)", line)
        if not m: continue
        pos, name, stack, enabled, _l, _s, fn = m.groups()
        v = re.search(r"-(v\d[^.]*(?:\.\d+)*(?:\+\d+)?)\.zip$", fn)
        if enabled == "false": name += " (disabled)"
        rows.append((pos, name, stack, v.group(1) if v else fn))
    return rows

def inject_extras(md, products_file, buildpacks_file):
    """Add the Deployed tiles / Buildpacks tables the renderer reads, if not already present."""
    if products_file and "**Deployed tiles:**" not in md:
        rows = parse_products(open(products_file, encoding="utf-8").read())
        if rows and "## 8. Certificates" in md:
            tbl = "**Deployed tiles:**\n\n| Tile | Deployed | Staged |\n|---|---|---|\n" + "".join(f"| {n} | {d} | {s} |\n" for n, d, s in rows) + "\n"
            md = md.replace("## 8. Certificates", tbl + "## 8. Certificates", 1)
    if buildpacks_file and "**Buildpacks:**" not in md:
        rows = parse_buildpacks(open(buildpacks_file, encoding="utf-8").read())
        if rows and "## 7. Upgrade Readiness" in md:
            tbl = "**Buildpacks:**\n\n| # | Buildpack | Stack | Version |\n|---|---|---|---|\n" + "".join(f"| {p} | {n} | {s} | {v} |\n" for p, n, s, v in rows) + "\n"
            md = md.replace("## 7. Upgrade Readiness", tbl + "## 7. Upgrade Readiness", 1)
    return md

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report", help="pcf-health-check.sh markdown report")
    ap.add_argument("--foundation", help="foundation code (default: first token of the report filename, upper-cased)")
    ap.add_argument("--author", default="Ben Chacko"); ap.add_argument("--date", help='header date, e.g. "October 15, 2026" (default: today)')
    ap.add_argument("--products", help="file with `om products` output"); ap.add_argument("--buildpacks", help="file with `cf buildpacks` output")
    ap.add_argument("--certs-3m", type=int, help="certs expiring within 3 months (om curl ... expires_within=3m)")
    ap.add_argument("-o", "--output", help="output PDF (default: <code>-health-dashboard-<yyyy-mm-dd>.pdf)")
    ap.add_argument("--png", action="store_true", help="also write <out>.png for e-mail embedding")
    ap.add_argument("--html", action="store_true", help="also keep <out>.html")
    a = ap.parse_args()
    if not a.foundation: a.foundation = os.path.basename(a.report).split("-")[0].split(".")[0].upper()
    if not a.date: a.date = _date.today().strftime("%B %-d, %Y")
    if not a.output: a.output = f"{a.foundation.lower()}-health-dashboard-{_date.today():%Y-%m-%d}.pdf"
    if not shutil.which("wkhtmltopdf"): sys.exit("wkhtmltopdf not found on PATH — see the dependency note at the top of this script")
    md = inject_extras(open(a.report, encoding="utf-8").read(), a.products, a.buildpacks); secs = sections(md); head = secs["_head"]; k = kv(head)

    # ---- headline ------------------------------------------------------
    verdict = re.search(r"Verdict: (\w+)\*\*", head); verdict = verdict.group(1).replace("_", " ") if verdict else "?"
    _sc = re.search(r"Health score: (\d+)%", head); score = int(_sc.group(1)) if _sc else (round(100 * ok / max(ok + warn + crit, 1)))
    _c = re.findall(r"\d+", k["Checks (OK / Warn / Crit)"]); ok, warn, crit = (int(_c[0]), int(_c[1]), int(_c[2])) if len(_c) >= 3 else (0, 0, 0)
    director = re.sub(r"`|—.*", "", k["Director"]).strip()
    generated = k["Generated"] or "unknown"; date = a.date or generated[:10]
    n_dep = len(k["Deployments"].split()); n_si = sum(1 for d in k["Deployments"].split() if d.startswith("service-instance"))
    vcol = {"READY": GREEN, "CAUTION": AMBER}.get(verdict.split()[0], RED)

    # ---- certificates --------------------------------------------------
    cm = re.search(r"(\d+) deployed, (\d+) within 1y", k["Certificates"])
    deployed, within_1y = (int(cm.group(1)), int(cm.group(2))) if cm else (None, None)
    m1 = re.search(r"(\d+) expiring ≤1m", k["Certificates"]); within_1m = int(m1.group(1)) if m1 else (0 if "none expiring" in k["Certificates"] else None)
    certs_unavail = "unavailable" in k["Certificates"] or not k["Certificates"]

    # ---- director ------------------------------------------------------
    bosh = find(secs, "BOSH Director")
    d_disk = {m.group(1): int(m.group(2)) for m in re.finditer(r"disk (\S+): (\d+)% used", bosh)}
    dm = re.search(r"memory: (\d+)% \((\d+)/(\d+) MB\)", bosh)
    dl = re.search(r"load ([\d.]+) over (\d+) vCPU", bosh)
    d_mem = int(dm.group(1)) if dm else None
    d_cpu = min(100, round(100 * float(dl.group(1)) / int(dl.group(2)))) if dl else None
    d_locks = "No active deployment locks" in bosh; d_tasks = re.search(r"(\d+) (?:in-flight |running )?BOSH task\(s\) (?:currently )?(?:running|in progress|in flight)", bosh) or re.search(r"(\d+) BOSH task(?!s ended)", bosh)
    d_failed = re.search(r"(\d+) of the last (\d+) BOSH tasks ended in 'error'", bosh)
    d_bbr = "bbr" in bosh and "failed" in bosh

    # ---- section table -------------------------------------------------
    sec_rows = [(m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)))
                for m in re.finditer(r"^\| ([A-Za-z /&()]+?) \| (\d+) \| (\d+) \| (\d+) \|$", find(secs, "Summary by section"), re.M)]

    # ---- VM utilization ------------------------------------------------
    util = find(secs, "VM Resource Utilization"); vms = []
    for m in re.finditer(r"^\| (\S+)/([0-9a-f]{8}) \| (\S+) \| (\d+) \| (\d+) \| (\d+) \| ([\d–-]+) \| \d+ \| ([\d.–-]+) \|$", util, re.M):
        vms.append(dict(ig=m.group(1), id=m.group(2), vmtype=m.group(3), cpu=int(m.group(4)), mem=int(m.group(5)), eph=int(m.group(6)),
                        per=int(m.group(7)) if m.group(7).isdigit() else None,
                        load=float(m.group(8)) if re.match(r"^[\d.]+$", m.group(8)) else None))
    thr = dict(mem=(85, 95), cpu=(80, 95), disk=(80, 90))

    # flagged VMs: deployment, instance, reason  (util + alloc + vm/process health)
    alloc = find(secs, "Allocated vs Utilized"); vmh = find(secs, "VM & Process Health")
    alloc_rows = {}
    for m in re.finditer(r"^\| (\S+)/([0-9a-f]{8}) \| \S+ \| (\S+ \S+) \| (\S+ \S+) \| .*? \| (\d+)% \|$", alloc, re.M):
        alloc_rows.setdefault(m.group(1), []).append((m.group(2), int(m.group(5)), m.group(3), m.group(4)))
    def dep_short(d):
        if d.startswith("service-instance_"): return "svc-inst " + d[17:25]
        return re.sub(r"-[0-9a-f]{20}$", "", d)
    flagged = []   # (sev, deployment, instance, reason)
    used = set()
    for m in re.finditer(r"^- (⚠️|❌) \[([^\]]+)\] (\S+) (CPU|memory|ephemeral disk|persistent disk|eph|per) (\d+)%", util, re.M):
        sev, dep, ig, metric, val = m.groups(); val = int(val)
        key = {"CPU": "cpu", "memory": "mem", "ephemeral disk": "eph", "eph": "eph", "persistent disk": "per", "per": "per"}.get(metric)
        cand = [v for v in vms if v["ig"] == ig and key and v[key] == val]
        fresh = [v for v in cand if (ig, v["id"], key) not in used]
        vid = (fresh or cand)[0]["id"] if cand else "?"
        used.add((ig, vid, key))
        lim = thr["cpu" if key == "cpu" else "disk" if key in ("eph", "per") else "mem"]
        flagged.append((sev, dep_short(dep), f"{ig}/{vid}", f"{metric} {val}% (≥{lim[1] if sev == '❌' else lim[0]}%)"))
    for m in re.finditer(r"^- (⚠️|❌) \[([^\]]+)\] (\S+) RAM allocation (\d+)% used \((.+?) of (.+?)\)", alloc, re.M):
        sev, dep, ig, val, usedgb, allocgb = m.groups(); val = int(val)
        cand = [r for r in alloc_rows.get(ig, []) if r[1] == val]; vid = cand[0][0] if cand else "?"
        flagged.append((sev, dep_short(dep), f"{ig}/{vid}", f"{val}% of {allocgb} RAM alloc"))
    for m in re.finditer(r"^- (⚠️|❌) \[([^\]]+)\] (.+)$", vmh, re.M):
        sev, dep, txt = m.groups()
        im = re.search(r"([\w-]+/[0-9a-f]{8})", txt)
        # Condense the check's verbose state line: "VM is unhealthy: x/uuid -> unresponsive agent; could not get monit status (...)"
        # becomes "unresponsive agent (monit unavailable)"; process lines become "process 'foo' not monitored".
        r = re.sub(r"[\w-]+/[0-9a-f-]{36}", "", txt)
        m2 = re.search(r"VM is unhealthy:?\s*-+>\s*([^;(]+)", r)
        if m2:
            reason = "VM " + m2.group(1).strip()
            if "could not get monit status" in r: reason += " (monit unavailable)"
        elif "could not get monit status" in r:
            reason = "monit status unavailable (agent/VM down)"
        else:
            m3 = re.search(r"process '([^']+)'.*?->\s*([^(]+)", r)
            reason = f"process {m3.group(1)} {m3.group(2).strip()}" if m3 else r.replace("->", "—").strip(" :-")[:90]
        flagged.append((sev, dep_short(dep), im.group(1) if im else "—", reason))
    # merge rows for the same VM so util + allocation flags read as one line
    merged = OrderedDict()
    for sev, dep, inst, reason in flagged:
        key = (dep, inst)
        if key in merged:
            psev, _, _, pr = merged[key]
            if "monit status unavailable" in reason and "VM " in pr: new_r = pr
            elif "monit status unavailable" in pr and "VM " in reason: new_r = reason
            else: new_r = pr + "; " + reason
            merged[key] = ("❌" if "❌" in (sev, psev) else "⚠️", dep, inst, new_r)
        else: merged[key] = (sev, dep, inst, reason)
    # bosh-health-check is BOSH's own canary deployment; its VM is constantly
    # created/destroyed, so an unresponsive agent there is noise, not a finding.
    flagged = sorted((f for f in merged.values() if "bosh-health" not in f[1] and "bosh-health-check" not in f[2]),
                     key=lambda f: (f[0] != "❌", f[1], f[2]))

    # ---- diego ---------------------------------------------------------
    diego = find(secs, "Diego Cells")
    # Cells summary line. Each field is picked out independently so a report
    # whose line differs slightly (extra LRP states, missing headroom, MB units)
    # degrades to zeros + a warning instead of crashing.
    cells_line = next((l for l in diego.splitlines() if l.startswith("**Cells:**")), "")
    def _num(pat, cast=float, default=0):
        m = re.search(pat, cells_line); return cast(m.group(1)) if m else default
    def _gb(pat):
        m = re.search(pat, cells_line)
        if not m: return 0.0
        v = float(m.group(1)); return v / 1024 if m.group(2).upper() == "MB" else v
    n_cells  = _num(r"\*\*Cells:\*\*\s*(\d+)", int)
    reserved = _gb(r"reserved/capacity\s*([\d.]+)\s*(GB|MB)")
    capacity = _gb(r"reserved/capacity\s*[\d.]+\s*(?:GB|MB)\s*/\s*([\d.]+)\s*(GB|MB)")
    res_pct  = _num(r"reserved/capacity[^(]*\((\d+)%\)", int)
    avail    = _gb(r"available\s*([\d.]+)\s*(GB|MB)")
    running  = _num(r"RUNNING=(\d+)", int)
    crashed  = _num(r"CRASHED=(\d+)", int)
    if not capacity:
        # fall back to summing the per-cell table: | id | Reserved | Capacity | Available | Containers | Reserved% |
        def _tog(v, u): return float(v) / 1024 if u.upper() == "MB" else float(v)
        rows = re.findall(r"^\| [0-9a-f]{8} \| ([\d.]+) (GB|MB) \| ([\d.]+) (GB|MB) \| ([\d.]+) (GB|MB) \|", diego, re.M)
        if rows:
            reserved = sum(_tog(r[0], r[1]) for r in rows); capacity = sum(_tog(r[2], r[3]) for r in rows); avail = sum(_tog(r[4], r[5]) for r in rows)
            n_cells = n_cells or len(rows)
            print(f"WARNING: '**Cells:**' summary line not parsed ({cells_line or '<missing>'}); totals summed from {len(rows)} cell rows instead", file=sys.stderr)
        else:
            print("WARNING: no Diego cell data found in '## 5. Diego Cells' — cell memory panels will be blank. Line was: " + (cells_line or "<missing>"), file=sys.stderr)
            capacity = 1.0  # keeps the donuts drawable; no_diego swaps them for a notice
    no_diego = capacity == 1.0 and reserved == 0
    if capacity and not res_pct: res_pct = round(100 * reserved / capacity)
    if not avail: avail = max(capacity - reserved, 0.0)
    cell_pcts = [int(m.group(1)) for m in re.finditer(r"^\| [0-9a-f]{8} \| .*? \| (\d+)% \|$", diego, re.M)]
    mif = re.search(r"max_in_flight (\d+)% → ≈(\d+) cell", k.get("max_in_flight", "") + diego)
    drain = re.search(r"absorbs ≈(\d+)", k["Diego cell headroom"])

    # ---- CF / upgrade / stemcells -------------------------------------
    api = find(secs, "Cloud Foundry API"); om = re.search(r"Orgs: (\d+) · Spaces: (\d+) · Apps: (\d+)", api)
    upg = find(secs, "Upgrade Readiness")
    orphan = re.search(r"(\d+) orphaned persistent disk", upg); orphan = int(orphan.group(1)) if orphan else 0
    stem_in_use = len(re.findall(r"esxi-", k["Stemcell(s) in use"]))
    stem_uploaded = sum(int(x) for x in re.findall(r"\((\d+)\)", re.search(r"Multiple stemcell versions present for: (.+?) —", upg).group(1))) if "Multiple stemcell" in upg else stem_in_use
    galera_ok = "✅" in find(secs, "MySQL"); api_ok = "✅ CF API reachable" in api
    locks_ok = d_locks and not d_tasks

    # Header counts: distinct problems, not raw checks. A VM failing two checks
    # (e.g. memory used + memory allocated) is one critical, matching the table.
    crit_body = find(secs, "Critical findings")
    crit_nonvm = len([l for l in crit_body.splitlines() if l.startswith("- ❌") and "bosh-health" not in l and "deployment lock" not in l and not re.search(r"\[(VM Resource Utilization|Allocated vs Utilized \(per VM\)|VM & Process Health)\]", l)])
    crit_vm = sum(1 for f in flagged if f[0] == "❌")
    crit_distinct = crit_vm + crit_nonvm

    # ================= charts =================
    charts = {}
    # 1 checks donut
    fig, ax = plt.subplots(figsize=(2.4, 2.9))
    ax.pie([ok, warn, crit_distinct], colors=[GREEN, AMBER, RED], startangle=90, counterclock=False,
           wedgeprops=dict(width=0.32, edgecolor="white"))
    ax.text(0, 0.08, f"{score}%", ha="center", va="center", fontsize=20, fontweight="bold", color=DARK)
    ax.text(0, -0.22, "health score", ha="center", va="center", fontsize=7, color=GREY)
    ax.set_title(f"{ok} OK · {warn} warn · {crit_distinct} crit", fontsize=8, color=DARK); charts["donut"] = png(fig)

    # 2 findings by section (warn/crit only, OK is the long tail)
    fig, ax = plt.subplots(figsize=(3.6, 2.9))
    names = [r[0].replace("Allocated vs Utilized (per VM)", "Alloc vs Util").replace("VM Resource Utilization", "VM Utilization").replace("MySQL / Galera Cluster", "MySQL/Galera").replace("Cloud Foundry API", "CF API") for r in sec_rows]
    y = np.arange(len(names)); w_ = [r[2] for r in sec_rows]; c_ = [r[3] for r in sec_rows]
    ax.barh(y, w_, color=AMBER, label="warn"); ax.barh(y, c_, left=w_, color=RED, label="crit")
    for i, (wv, cv, okv) in enumerate(zip(w_, c_, [r[1] for r in sec_rows])):
        ax.text(wv + cv + 0.2, i, f"{wv + cv}  ({okv} ok)", va="center", fontsize=6.5, color=GREY)
    ax.set_yticks(y); ax.set_yticklabels(names, fontsize=7); ax.invert_yaxis()
    ax.set_xlim(0, max(1, max(x + z for x, z in zip(w_, c_))) * 1.6); ax.set_xlabel("flagged checks", fontsize=7)
    ax.set_title("Findings by section"); ax.legend(fontsize=6.5, frameon=False, loc="lower right"); charts["sections"] = png(fig)

    # 3 certificates
    fig, ax = plt.subplots(figsize=(3.2, 2.7))
    if certs_unavail:
        ax.text(0.5, 0.5, "Expiry unavailable\nfrom Ops Manager —\nverify manually" if k["Certificates"] else "Not reported\nby this check", ha="center", va="center", fontsize=8, color=AMBER, transform=ax.transAxes); ax.axis("off")
    else:
        labels = ["≤ 1 month", "≤ 3 months", "≤ 1 year", "deployed"]
        vals = [within_1m, a.certs_3m, within_1y, deployed]
        cols = [RED if within_1m else GREEN, AMBER if a.certs_3m else GREY, AMBER, GREY]
        top = deployed or max([v for v in vals if v] or [1])
        bars = ax.bar(labels, [v or 0 for v in vals], color=cols)
        for b, v in zip(bars, vals):
            ax.text(b.get_x() + b.get_width() / 2, (b.get_height() or 0) + top * 0.03, "n/a" if v is None else str(v), ha="center", fontsize=7.5, color=DARK, fontweight="bold")
        ax.set_ylim(0, top * 1.18); ax.tick_params(axis="x", labelsize=6.5); ax.set_yticks([])
        ax.spines["left"].set_visible(False)
    ax.set_title("Certificates expiring"); charts["certs"] = png(fig)

    # 4 director
    fig, ax = plt.subplots(figsize=(4.2, 2.7))
    if d_mem is None:
        ax.text(0.5, 0.55, "Not collected —\nbbr SSH to the\nDirector VM failed" if d_bbr else "Not collected", ha="center", va="center", fontsize=8, color=AMBER, transform=ax.transAxes)
        ax.text(0.5, 0.18, "Director reachable, " + ("no locks/tasks" if locks_ok else "tasks/locks present"), ha="center", fontsize=7, color=GREEN if locks_ok else AMBER, transform=ax.transAxes); ax.axis("off")
    else:
        labels = ["CPU\n(load/vCPU)", "Memory"] + [f"disk\n{p.replace('/var/vcap/', '')}" for p in d_disk]
        vals = [d_cpu, d_mem] + list(d_disk.values())
        cols = [RED if v >= 95 else AMBER if v >= 80 else ORANGE for v in vals]
        bars = ax.bar(labels, vals, color=cols)
        for b, v in zip(bars, vals): ax.text(b.get_x() + b.get_width() / 2, v + 2, f"{v}%", ha="center", fontsize=7.5, color=DARK)
        ax.axhline(80, color=AMBER, lw=0.8, ls="--"); ax.axhline(95, color=RED, lw=0.8, ls="--")
        ax.set_ylim(0, 110); ax.set_yticks([0, 50, 100]); ax.tick_params(axis="x", labelsize=6)
    ax.set_title("BOSH Director VM"); charts["director"] = png(fig)

    def notice(title, size, text="Diego cell data\nnot in this report"):
        fig, ax = plt.subplots(figsize=size); ax.axis("off")
        ax.text(0.5, 0.5, text, ha="center", va="center", fontsize=8, color=AMBER, transform=ax.transAxes)
        ax.set_title(title); return png(fig)

    # 5 diego capacity donut
    if no_diego:
        charts["diego"] = notice("Reserved", (2.4, 2.9))
    else:
        fig, ax = plt.subplots(figsize=(2.4, 2.9))
        ax.pie([reserved, avail] if reserved + avail > 0 else [0, 1], colors=[ORANGE, LIGHT], startangle=90, counterclock=False, wedgeprops=dict(width=0.32, edgecolor="white"))
        ax.text(0, 0.1, f"{res_pct}%", ha="center", va="center", fontsize=18, fontweight="bold", color=DARK)
        ax.text(0, -0.2, "of cell memory", ha="center", fontsize=7, color=GREY)
        ax.text(0, -1.32, f"{reserved:,.0f} / {capacity:,.0f} GB total memory", ha="center", va="top", fontsize=7.5, color=GREY)
        ax.set_title("Reserved"); charts["diego"] = png(fig)

    # 6 cell memory totals: capacity vs reserved vs actually used (GB)
    if no_diego:
        charts["cells"] = notice("Cell memory details", (3.2, 2.4))
    else:
        def to_gb(t):
            v, u = t.split(); v = float(v); return v / 1024 if u == "MB" else v
        actual_gb = sum(to_gb(r[2]) for ig, rows in alloc_rows.items() if "diego_cell" in ig for r in rows)
        bars = [("Total capacity", capacity, LIGHT, DARK), ("Reserved by apps", reserved, ORANGE, "white"), ("Actually used", actual_gb, GREEN, "white")]
        fig, ax = plt.subplots(figsize=(3.0, 2.4))
        for i, (lab, val, col, tc) in enumerate(bars):
            ax.barh(i, val, color=col, height=0.6)
            ax.text(val / 2 if val > capacity * 0.5 else val + capacity * 0.02, i, f"{val:,.0f} GB" + ("" if i == 0 else f"  ({100 * val / capacity:.0f}%)"),
                    ha="center" if val > capacity * 0.5 else "left", va="center", fontsize=8, color=tc if val > capacity * 0.5 else DARK, fontweight="bold")
        ax.set_yticks(range(3)); ax.set_yticklabels([b[0] for b in bars], fontsize=8); ax.invert_yaxis(); ax.tick_params(axis="y", length=0)
        ax.set_xlim(0, capacity * 1.05); ax.set_xticks([]); ax.spines["bottom"].set_visible(False); ax.spines["left"].set_visible(False)
        ax.set_title("Cell memory details"); charts["cells"] = png(fig)

    # 6b actual-used donut (same style as the reserved donut)
    if no_diego:
        charts["actual"] = notice("Actual", (2.4, 2.9))
    else:
        fig, ax = plt.subplots(figsize=(2.4, 2.9))
        ax.pie([actual_gb, max(capacity - actual_gb, 0)] if capacity > 0 else [0, 1], colors=[GREEN, LIGHT], startangle=90, counterclock=False, wedgeprops=dict(width=0.32, edgecolor="white"))
        ax.text(0, 0.1, f"{100 * actual_gb / capacity:.0f}%", ha="center", va="center", fontsize=18, fontweight="bold", color=DARK)
        ax.text(0, -0.2, "of cell memory", ha="center", fontsize=7, color=GREY)
        ax.text(0, -1.32, f"{actual_gb:,.0f} / {capacity:,.0f} GB total memory", ha="center", va="top", fontsize=7.5, color=GREY)
        ax.set_title("Actual"); charts["actual"] = png(fig)

    # 7 LRPs
    if no_diego:
        charts["lrps"] = notice("App Instances", (2.4, 2.9), "LRP counts\nnot in this report")
    else:
        fig, ax = plt.subplots(figsize=(2.4, 2.9))
        ax.pie([running, crashed] if running + crashed > 0 else [0, 1], colors=[GREEN, RED], startangle=90, counterclock=False, wedgeprops=dict(width=0.32, edgecolor="white"))
        ax.text(0, 0.1, f"{running:,}", ha="center", va="center", fontsize=16, fontweight="bold", color=DARK)
        ax.text(0, -0.2, "running", ha="center", fontsize=7, color=GREY)
        ax.text(0, -1.32, f"{crashed} crashed", ha="center", va="top", fontsize=8, color=GREY)
        ax.set_title("App Instances"); charts["lrps"] = png(fig)

    # 8 VMs within / warn / crit per resource (stacked bars)
    def bucket(vals, lim):
        return [sum(1 for v in vals if v < lim[0]), sum(1 for v in vals if lim[0] <= v < lim[1]), sum(1 for v in vals if v >= lim[1])]
    res = [("Memory", bucket([v["mem"] for v in vms], thr["mem"])), ("CPU", bucket([v["cpu"] for v in vms], thr["cpu"])), ("Disk", bucket([v["eph"] for v in vms], thr["disk"]))]
    fig, ax = plt.subplots(figsize=(2.9, 2.4))
    for i, (name, (okn, wn, cn)) in enumerate(res):
        ax.barh(i, okn, color=GREEN, height=0.6); ax.barh(i, wn, left=okn, color=AMBER, height=0.6); ax.barh(i, cn, left=okn + wn, color=RED, height=0.6)
        txt = f"{okn} ok" + (f"  ·  {wn} warn" if wn else "") + (f"  ·  {cn} crit" if cn else "")
        ax.text(len(vms) * 1.03, i, txt, va="center", fontsize=8, color=AMBER if (wn or cn) else GREEN, fontweight="bold" if (wn or cn) else "normal")
    ax.set_yticks(range(len(res))); ax.set_yticklabels([r[0] for r in res], fontsize=9); ax.invert_yaxis()
    ax.set_xlim(0, len(vms) * 2.3); ax.set_xticks([]); ax.spines["bottom"].set_visible(False); ax.spines["left"].set_visible(False); ax.tick_params(axis="y", length=0)
    ax.set_title(f"{len(vms)} VMs vs warn/crit thresholds"); charts["vmdist"] = png(fig)

    # 8b Gorouter VMs: status word + two gauges (CPU, memory) showing avg and busiest router
    routers = [v for v in vms if v["ig"] == "router"]
    fig, ax = plt.subplots(figsize=(3.2, 2.7)); ax.axis("off")
    if routers:
        cpu_v = [v["cpu"] for v in routers]; mem_v = [v["mem"] for v in routers]
        hot = sum(1 for v in routers if v["cpu"] >= thr["cpu"][0] or v["mem"] >= thr["mem"][0])
        r_crit = sum(1 for v in routers if v["cpu"] >= thr["cpu"][1] or v["mem"] >= thr["mem"][1])
        word, wcol = ("Unhealthy", RED) if r_crit else ("Degraded", AMBER) if hot else ("Healthy", GREEN)
        ax.text(0.5, 0.97, f"{len(routers)} Gorouter VMs · {routers[0]['vmtype']}", ha="center", va="top", fontsize=9, fontweight="bold", color=DARK, transform=ax.transAxes)
        ax.text(0.5, 0.83, "Vitals", ha="center", va="top", fontsize=20, fontweight="bold", color=DARK, transform=ax.transAxes)
        ax.text(0.5, 0.63, "all within thresholds" if not hot else f"{hot} of {len(routers)} over the warning line", ha="center", va="top", fontsize=7.5, color=GREY, transform=ax.transAxes)
        gax = fig.add_axes([0.2, 0.08, 0.72, 0.42])
        for i, (lab, vals, lim) in enumerate([("CPU", cpu_v, thr["cpu"]), ("Memory", mem_v, thr["mem"])]):
            mx, av = max(vals), sum(vals) / len(vals)
            gax.barh(i, 100, color=LIGHT, height=0.5)
            gax.barh(i, mx, color=RED if mx >= lim[1] else AMBER if mx >= lim[0] else GREEN, height=0.5)
            gax.plot([av, av], [i - 0.3, i + 0.3], color=DARK, lw=1.2)
            gax.text(mx + 2, i, f"max {mx}%  ·  avg {av:.0f}%", va="center", fontsize=7, color=DARK)
            gax.axvline(lim[0], color=AMBER, lw=0.8, ls="--"); gax.axvline(lim[1], color=RED, lw=0.8, ls="--")
        gax.set_yticks([0, 1]); gax.set_yticklabels(["CPU", "Memory"], fontsize=8); gax.invert_yaxis(); gax.tick_params(axis="y", length=0)
        gax.set_xlim(0, 100); gax.set_xticks([]); [gax.spines[k].set_visible(False) for k in gax.spines]
        busiest = max(routers, key=lambda v: v["load"] or 0)
        fig.text(0.5, 0.0, f"busiest: router/{busiest['id']} (CPU {busiest['cpu']}%, load {busiest['load']:.1f})", ha="center", fontsize=6.5, color=GREY)
    else:
        ax.text(0.5, 0.5, "No router VMs found", ha="center", va="center", transform=ax.transAxes, color=AMBER)
    charts["gorouter"] = png(fig)

    # 9 flagged VMs table (HTML, not a chart)
    MAXR = 8
    rows = "".join(f'<tr><td style="color:{RED if f[0]=="❌" else AMBER};font-weight:bold">{"✘" if f[0]=="❌" else "⚠"}</td><td>{f[1]}</td><td class="mono">{f[2]}</td><td>{f[3]}</td></tr>' for f in flagged[:MAXR])
    more = f'<tr><td></td><td colspan="3" style="color:#999">… {len(flagged)-MAXR} more in the full report</td></tr>' if len(flagged) > MAXR else ""
    if not flagged: rows = f'<tr><td colspan="4" style="color:{GREEN};text-align:center;padding:30px 0">No VMs flagged</td></tr>'
    # 9a critical findings table (one row per distinct problem; same rules as the header count)
    crit_rows = []
    for f in flagged:
        if f[0] == "❌": crit_rows.append((f[1], f"{f[2]} — {f[3]}"))
    for l in crit_body.splitlines():
        if not l.startswith("- ❌") or "bosh-health" in l or "deployment lock" in l: continue
        if re.search(r"\[(VM Resource Utilization|Allocated vs Utilized \(per VM\)|VM & Process Health)\]", l): continue
        m = re.match(r"- ❌ \*\*\[(.+?)\]\*\* (.*)", l)
        area, txt = (m.group(1), m.group(2)) if m else ("", l[4:])
        txt = txt.replace("— little room to place more containers.", "— little room to place more containers").rstrip(".")
        crit_rows.append((area, txt))
    MAXC = 6
    crows = "".join(f'<tr><td style="color:{RED};font-weight:bold">✘</td><td>{a}</td><td>{t}</td></tr>' for a, t in crit_rows[:MAXC])
    cmore = f'<tr><td></td><td colspan="2" style="color:#999">… {len(crit_rows)-MAXC} more in the full report</td></tr>' if len(crit_rows) > MAXC else ""
    if not crit_rows: crows = f'<tr><td colspan="3" style="color:{GREEN};text-align:center;padding:8px 0">No critical findings</td></tr>'
    # 9c deployed tiles table — from the "**Deployed tiles:**" table that
    # pcf-health-check.sh (2026-10-14+) writes from `om products`:
    # | Tile | Deployed | Staged |. Older reports have none -> block omitted.
    tiles_md = re.search(r"\*\*Deployed tiles:\*\*\s*\n\n\| Tile \| Deployed \| Staged \|\n\|[-| ]+\|\n((?:\|.*\|\n?)+)", upg)
    tile_rows = []
    if tiles_md:
        for line in tiles_md.group(1).strip().splitlines():
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) == 3: tile_rows.append(cells)
    if tile_rows:
        half = (len(tile_rows) + 1) // 2
        def trow(n, d, st):
            mism = st and st != d
            stc = f'<span style="color:{AMBER};font-weight:bold">{st} ⚠</span>' if mism else st
            return f'<tr><td>{n}</td><td class="mono">{d}</td><td class="mono">{stc}</td></tr>'
        def trows(rows): return "".join(trow(*r) for r in rows)
        charts["tiletable"] = (f'<div class="ttl">Deployed tiles ({len(tile_rows)})</div>'
            f'<table class="tiles2"><tr><td style="width:50%;vertical-align:top;padding:0 6px 0 0"><table class="flag"><tr><th>Tile</th><th>Deployed</th><th>Staged</th></tr>{trows(tile_rows[:half])}</table></td>'
            f'<td style="width:50%;vertical-align:top;padding:0 0 0 6px"><table class="flag"><tr><th>Tile</th><th>Deployed</th><th>Staged</th></tr>{trows(tile_rows[half:])}</table></td></tr></table>')
    else:
        charts["tiletable"] = ""

    # 9d buildpacks table — from a "**Buildpacks:**" table anywhere in the
    # report (| # | Buildpack | Stack | Version |, as `cf buildpacks` lists
    # them, position order). Three columns; omitted when the report has none.
    bp_md = re.search(r"\*\*Buildpacks:\*\*\s*\n\n\| # \| Buildpack \| Stack \| Version \|\n\|[-| ]+\|\n((?:\|.*\|\n?)+)", md)
    bp_rows = []
    if bp_md:
        for line in bp_md.group(1).strip().splitlines():
            cells = [c.strip() for c in line.strip("|").split("|")]
            if len(cells) == 4: bp_rows.append(cells)
    if bp_rows:
        per = (len(bp_rows) + 2) // 3
        cols = [bp_rows[i*per:(i+1)*per] for i in range(3)]
        def bprow(p, n, s, v): return f'<tr><td style="color:#999;text-align:right">{p}</td><td>{n}</td><td>{s}</td><td class="mono">{v}</td></tr>'
        def bpcol(rows, pad): return (f'<td style="width:33.3%;vertical-align:top;padding:{pad}"><table class="flag bp"><tr><th>#</th><th>Buildpack</th><th>Stack</th><th>Version</th></tr>'
                                      + "".join(bprow(*r) for r in rows) + '</table></td>')
        charts["bptable"] = (f'<div class="ttl">Buildpacks ({len(bp_rows)})</div>'
            f'<table class="tiles2"><tr>{bpcol(cols[0], "0 4px 0 0")}{bpcol(cols[1], "0 4px")}{bpcol(cols[2], "0 0 0 4px")}</tr></table>')
    else:
        charts["bptable"] = ""

    charts["crittable"] = "" if not crit_rows else f'<div class="ttl">Critical findings ({len(crit_rows)})</div><table class="flag crit"><tr><th></th><th>Area</th><th>Finding</th></tr>{crows}{cmore}</table>'

    charts["flagtable"] = "" if not flagged else f'<div class="ttl">Flagged VMs ({len(flagged)})</div><table class="flag"><tr><th></th><th>Deployment</th><th>Instance</th><th>Reason</th></tr>{rows}{more}</table>'

    # ================= HTML =================
    def tile(label, value, sub="", color=DARK):
        return f'<div class="tile"><div class="v" style="color:{color}">{value}</div><div class="l">{label}</div><div class="s">{sub}</div></div>'
    def status(okv, txt_ok, txt_bad):
        return f'<span style="color:{GREEN if okv else AMBER};font-weight:bold">{"✔" if okv else "⚠"}</span> {txt_ok if okv else txt_bad}'
    n_flag = sum(1 for v in vms if v["mem"] >= thr["mem"][0] or v["cpu"] >= thr["cpu"][0] or v["eph"] >= thr["disk"][0])
    tiles = "".join([
        tile("deployments", n_dep, f"{n_si} on-demand service instances"),
        tile("VMs checked", len(vms), f"{n_flag} flagged for CPU/memory/disk" if n_flag else "none flagged for CPU/memory/disk", AMBER if n_flag else GREEN),
        tile("Diego cells", n_cells if not no_diego else "n/a", (f"drain ceiling ≈{drain.group(1) if drain else '?'} · {('≈' + mif.group(2) + ' per batch') if mif else ''}") if not no_diego else "cfdot/BBS unreachable", DARK if not no_diego else AMBER),
        tile("orgs / spaces / apps", f"{om.group(1)} / {om.group(2)} / {int(om.group(3)):,}" if om else "n/a", "" if om else "CF CLI not targeted", DARK if om else AMBER),
        tile("stemcell versions", f"{stem_in_use} in use", f"{stem_uploaded} uploaded — bosh clean-up" if stem_uploaded > stem_in_use else "tidy", AMBER if stem_uploaded > stem_in_use else GREEN),
    ])
    checks = "<br>".join([
        status(locks_ok, "No deployment locks or running tasks", f"{d_tasks.group(1) + ' BOSH task(s) running' if d_tasks else 'deployment lock active'}"),
        status(not d_bbr, "Director VM checks collected", "Director VM checks skipped (bbr SSH failed)"),
        status(api_ok, "CF API reachable", "CF API checks skipped"),
        status(galera_ok, "Galera cluster synced", "Galera state unverified — run mysql-diag"),
        status(not certs_unavail and not within_1m, "No certificates expiring within 1 month", "Certificate expiry needs attention"),
        status(crashed == 0, "No crashed app instances", f"{crashed} crashed app instances"),
    ])
    # ---- healthy / unhealthy boxes ------------------------------------
    def box(name, state, detail):
        col = {"Healthy": GREEN, "Unhealthy": RED, "Enabled": GREEN, "Disabled": RED}.get(state, AMBER)
        return (f'<div class="box" style="border-top:4px solid {col}"><div class="bn">{name}</div>'
                f'<div class="bs" style="color:{col}">{state}</div><div class="bd">{detail}</div></div>')
    # A deployment lock is usually just the bosh-health-check deployment (or an
    # in-flight apply); Ben wants it noted in the detail line, not Unhealthy.
    dir_crit = "Director reachable" not in bosh or any(
        l.startswith("- ❌") and "deployment lock" not in l and "resurrector" not in l.lower() for l in bosh.splitlines())
    # Resurrector box (same as the TKGI dashboard): header row "| **Resurrector** | … |"
    # written by pcf-health-check.sh from `bosh curl /resurrection`; falls back to
    # the section-1 finding. Reports that predate the check read as Unverified.
    res_src = (k.get("Resurrector", "") + " " + " ".join(l for l in bosh.splitlines() if "resurrector" in l.lower())).lower()
    if "disabled" in res_src: res_state, res_detail = "Disabled", "bosh update-resurrection on"
    elif "enabled" in res_src: res_state, res_detail = "Enabled", "failed VMs are recreated automatically"
    else: res_state, res_detail = "Unverified", ("bosh curl /resurrection unavailable" if res_src.strip() else "not in this report — re-run the health check")
    dir_warns = []
    if d_tasks: dir_warns.append(f"{d_tasks.group(1)} BOSH task(s) running")
    if d_failed: dir_warns.append(f"{d_failed.group(1)} of last {d_failed.group(2)} tasks errored")
    if not d_locks: dir_warns.append("deployment lock active")
    if d_bbr: dir_warns.append("VM checks skipped — bbr SSH failed")
    dir_detail = "; ".join(dir_warns) if dir_warns else (f"CPU {d_cpu}% · mem {d_mem}% · disk " + "/".join(f"{v}%" for v in d_disk.values()) if d_mem is not None else "reachable, no locks or tasks")
    api_detail = f"{om.group(1)} orgs · {om.group(2)} spaces · {int(om.group(3)):,} apps" if om else ("reachable" if api_ok else "CF CLI not targeted — checks skipped")
    mysql_sec = find(secs, "MySQL")
    m_syn = re.search(r"(\d+)/(\d+) nodes Synced/Primary", mysql_sec)
    if galera_ok:
        mysql_state, mysql_detail = "Healthy", (f"{m_syn.group(1)}/{m_syn.group(2)} nodes Synced/Primary, seqno in step" if m_syn else "all nodes Synced")
    elif "❌" in mysql_sec:
        mysql_state = "Unhealthy"
        mysql_detail = f"only {m_syn.group(1)} of {m_syn.group(2)} nodes Synced/Primary" if m_syn else "node(s) not Synced"
    elif "seqnos differ" in mysql_sec:
        mysql_state = "Catching up"
        mysql_detail = f"{m_syn.group(1)}/{m_syn.group(2)} Synced/Primary but seqnos differ — re-check before upgrading" if m_syn else "nodes Synced but seqnos differ"
    else:
        mysql_state, mysql_detail = "Unverified", "mysql-diag inconclusive — verify manually"
    routers = [v for v in vms if v["ig"] == "router"]
    if routers:
        r_hot = sum(1 for v in routers if v["cpu"] >= thr["cpu"][0] or v["mem"] >= thr["mem"][0])
        r_bad = sum(1 for v in routers if v["cpu"] >= thr["cpu"][1] or v["mem"] >= thr["mem"][1])
        gr_state = "Unhealthy" if r_bad else ("Degraded" if r_hot else "Healthy")
        gr_detail = f"{len(routers)} VMs · max CPU {max(v['cpu'] for v in routers)}% · max mem {max(v['mem'] for v in routers)}%" + (f" · {r_hot} over warn line" if r_hot else "")
    else:
        gr_state, gr_detail = "Unverified", "no router VMs in report"
    boxes = box("BOSH Director", "Unhealthy" if dir_crit else "Healthy", dir_detail) + \
            box("Cloud Foundry API", "Healthy" if api_ok else "Unhealthy", api_detail) + \
            box("Resurrector", res_state, res_detail) + \
            box("Gorouter", gr_state, gr_detail) + \
            box("MySQL / Galera", mysql_state, mysql_detail)

    def block(html): return f'<div class="grid"><div class="row"><div class="cell" style="text-align:left">{html}</div></div></div><div style="height:6px"></div>' if html else ""
    crit_block = block(charts["crittable"]); flag_block = block(charts["flagtable"])
    tile_block = f'<div style="height:6px"></div><div class="grid"><div class="row"><div class="cell" style="text-align:left">{charts["tiletable"]}</div></div></div>' if charts["tiletable"] else ""
    bp_block = f'<div style="height:6px"></div><div class="grid"><div class="row"><div class="cell" style="text-align:left">{charts["bptable"]}</div></div></div>' if charts["bptable"] else ""
    html = f"""<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body{{font-family:DejaVu Sans,Arial,sans-serif;color:{DARK};margin:0;font-size:9px}}
.hdr{{display:flex;justify-content:space-between;align-items:flex-end;background:#f5f5f5;border-radius:6px;padding:10px 14px 10px;margin-bottom:10px}}
h1{{font-size:17px;margin:0;color:{ORANGE};font-weight:normal}} .sub{{color:#555;font-size:9px;margin-top:2px}} .meta{{color:#777;font-size:8px}}
.verdict{{font-size:12px;font-weight:bold;color:{ORANGE};text-align:right;letter-spacing:.5px}}
.grid{{display:table;width:100%;border-spacing:6px 0}} .row{{display:table-row}} .cell{{display:table-cell;vertical-align:top;border:1px solid {LIGHT};border-radius:4px;padding:4px;text-align:center}}
.cell img{{max-width:100%}}
.tiles{{display:table;width:100%;border-spacing:6px 0;margin:6px 0}} .tile{{display:table-cell;width:20%;text-align:center;background:#f5f5f5;border-radius:4px;padding:9px 2px}}
.tile .v{{font-size:18px;font-weight:bold}} .tile .l{{font-size:7.5px;color:#777;text-transform:uppercase;letter-spacing:.3px}} .tile .s{{font-size:7px;color:#999;margin-top:2px}}
.checks{{text-align:left;font-size:9.5px;line-height:1.8;padding:6px 10px}}
.ttl{{font-weight:bold;font-size:9px;text-align:center;margin:3px 0 4px}} table.flag{{border-collapse:collapse;width:100%;font-size:8.5px;table-layout:fixed}} table.flag th:nth-child(1){{width:3%}} table.flag th:nth-child(2){{width:27%}} table.flag th:nth-child(3){{width:30%}} table.tiles2{{width:100%;border-collapse:collapse}} table.tiles2 table.flag th:nth-child(1){{width:50%}} table.tiles2 table.flag th:nth-child(2){{width:25%}} table.tiles2 table.flag th:nth-child(3){{width:25%}} table.tiles2 table.flag td{{padding:0 3px;font-size:7.3px;line-height:1.25}} table.tiles2 table.flag th{{padding:0 3px;font-size:7.3px}} table.tiles2 table.bp th:nth-child(1){{width:6%}} table.tiles2 table.bp th:nth-child(2){{width:46%}} table.tiles2 table.bp th:nth-child(3){{width:22%}} table.tiles2 table.bp th:nth-child(4){{width:26%}} table.tiles2 table.bp td{{padding:0 2px;font-size:6.8px;line-height:1.25;white-space:nowrap;overflow:hidden}} table.crit th:nth-child(2){{width:22%}} table.crit th:nth-child(3){{width:auto}} table.flag th{{text-align:left;color:#777;font-weight:normal;border-bottom:1px solid #ccc;padding:1px 3px}} table.flag td{{padding:2px 3px;border-bottom:1px solid #eee;vertical-align:top}} .mono{{font-family:DejaVu Sans Mono,monospace;font-size:8px}}
.boxes{{display:table;width:100%;border-spacing:6px 0;margin:0 0 2px}} .box{{display:table-cell;width:20%;text-align:center;background:#fafafa;border:1px solid #E6E6E6;border-radius:4px;padding:8px 6px}} .bn{{font-size:9px;color:#555;text-transform:uppercase;letter-spacing:.4px}} .bs{{font-size:18px;font-weight:bold;margin:2px 0}} .bd{{font-size:8px;color:#777}}
.foot{{border-top:1px solid {LIGHT};margin-top:8px;padding-top:4px;color:#999;font-size:7.5px;text-align:center}}
</style></head><body>
<div class="hdr"><div><img src="{LOGO_URI}" width="90"/><h1>Foundation Health Check — {a.foundation}</h1>
<div class="sub">{director}</div><div class="meta">Prepared by {a.author} · {date} · generated {generated} · Internal Use</div></div>
<div class="verdict">STATUS<br><span style="font-weight:normal;color:#555;font-size:9px">{crit_distinct} critical · {warn} warnings</span></div></div>
<div class="boxes">{boxes}</div>
<div class="tiles">{tiles}</div>
{crit_block}{flag_block}<div class="grid">
<div class="row"><div class="cell" style="width:22%;vertical-align:middle"><img src="{charts['donut']}" style="max-height:190px"/></div><div class="cell" style="width:28%;vertical-align:middle"><img src="{charts['certs']}" style="max-height:210px"/></div><div class="cell" style="width:28%;vertical-align:middle"><img src="{charts['gorouter']}" style="max-height:210px"/></div><div class="cell" style="width:22%;vertical-align:middle"><img src="{charts['lrps']}" style="max-height:190px"/></div></div>
</div><div style="height:6px"></div><div class="grid">
<div class="row"><div class="cell" style="width:30%"><img src="{charts['diego']}" style="max-height:200px"/></div><div class="cell" style="width:40%"><img src="{charts['cells']}" style="max-height:200px"/></div><div class="cell" style="width:30%"><img src="{charts['actual']}" style="max-height:200px"/></div></div>
</div>{tile_block}{bp_block}
<div class="foot">Fiserv — Internal Use · {a.foundation} Foundation Health Check · thresholds: memory 85/95%, CPU 80/95%, disk 80/90% (warn/crit) · generated by pcf-health-check.sh; ≤3-month certificate count is not reported by the check (use om curl expires_within=3m)</div>
</body></html>"""
    stem = a.output[:-4] if a.output.lower().endswith(".pdf") else a.output
    tmp = tempfile.mkdtemp()
    html_path = os.path.join(tmp, "dashboard.html")
    open(html_path, "w", encoding="utf-8").write(html)
    margins = ["--margin-top", "10mm", "--margin-bottom", "10mm", "--margin-left", "10mm", "--margin-right", "10mm"]
    subprocess.run(["wkhtmltopdf", "-q", "--enable-local-file-access", "--page-size", "Letter", *margins, html_path, a.output],
                   check=True, stderr=subprocess.DEVNULL)
    print(f"wrote {a.output}")
    if a.png:
        if not shutil.which("wkhtmltoimage"): sys.exit("wkhtmltoimage not found (it ships with wkhtmltopdf)")
        subprocess.run(["wkhtmltoimage", "-q", "--enable-local-file-access", "--width", "1600", "--zoom", "1.96", "--quality", "92", html_path, stem + ".png"],
                       check=True, stderr=subprocess.DEVNULL)
        try:  # wkhtmltoimage writes uncompressed PNG (~8 MB); re-save compressed if Pillow is available
            from PIL import Image
            im = Image.open(stem + ".png"); im = im.convert("P", palette=Image.ADAPTIVE, colors=256); im.save(stem + ".png", optimize=True)
        except ImportError:
            print("note: install Pillow (python3-pil) to shrink the PNG ~10x", file=sys.stderr)
        print(f"wrote {stem}.png")
    if a.html:
        shutil.copy(html_path, stem + ".html"); print(f"wrote {stem}.html")
    shutil.rmtree(tmp, ignore_errors=True)
    if shutil.which("pdfinfo"):
        info = subprocess.run(["pdfinfo", a.output], capture_output=True, text=True).stdout
        m = re.search(r"^Pages:\s+(\d+)", info, re.M)
        if m and m.group(1) != "1": print(f"WARNING: {a.output} has {m.group(1)} pages — expected 1", file=sys.stderr)

if __name__ == "__main__":
    main()
