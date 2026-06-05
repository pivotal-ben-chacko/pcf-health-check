# PCF FOG Foundation Health Check

> **⚠️ Verdict: CAUTION** — PROCEED WITH CAUTION — 4 warning(s); review before upgrading.
>
> **Health score: 84%**

| | |
|---|---|
| **Director** | `192.168.2.2` — p-bosh v282.1.11 (00000000) (vsphere_cpi) |
| **Generated** | 2026-06-05 04:42 UTC |
| **Run on** | `ubuntu@opsman-skynetsystems-io` |
| **Deployments** | cf-6f11f8e43cd7b626077b |
| **Stemcell(s) in use** | bosh-vsphere-esxi-ubuntu-jammy-go_agent/1.1193 |
| **Checks (OK / Warn / Crit)** | 54 / 4 / 0 |
| **Health score** | **84%** |

## Summary by section

| Section | ✅ OK | ⚠️ Warn | ❌ Crit |
|---|--:|--:|--:|
| BOSH Director | 7 | 2 | 0 |
| VM & Process Health | 1 | 0 | 0 |
| VM Resource Utilization | 20 | 0 | 0 |
| Allocated vs Utilized (per VM) | 20 | 0 | 0 |
| Diego Cells | 1 | 0 | 0 |
| Cloud Foundry API | 1 | 0 | 0 |
| Upgrade Readiness | 2 | 2 | 0 |
| Certificates | 1 | 0 | 0 |
| MySQL / Galera Cluster | 1 | 0 | 0 |

## 1. BOSH Director

- ✅ Director reachable: p-bosh (v282.1.11 (00000000), vsphere_cpi)
- ✅ No active deployment locks.
- ✅ No in-flight BOSH tasks.
- ⚠️ 8 of the last 25 BOSH tasks ended in 'error' (review with: bosh tasks --recent=25).
- ⚠️ Director VM disk /var/vcap/store at 84% used.
- ✅ disk /var/vcap/data: 11% used
- ✅ disk /: 71% used
- ✅ memory: 36% (2868/7937 MB)
- ✅ monit: all 23 director processes running

_Director VM: memory 36% (2868/7937 MB), load 0.05 over 2 vCPU, 23 monit processes running._

## 2. VM & Process Health

- ✅ [cf-6f11f8e43cd7b626077b] all 20 VM(s) and their processes are running.

## 3. VM Resource Utilization

| Instance | VM Type | CPU% | Mem% | Eph% | Per% | Sys% | Load |
|---|---|--:|--:|--:|--:|--:|--:|
| clock_global/3586f01c | medium.disk | 2 | 23 | 20 | – | 59 | 1.57 |
| cloud_controller/2d5c0972 | large.disk | 3 | 13 | 23 | – | 59 | 0.10 |
| cloud_controller_worker/2bf613b3 | micro | 2 | 52 | 10 | – | 59 | 0.00 |
| credhub/7034e814 | xlarge.mem | 1 | 3 | 5 | – | 59 | 0.00 |
| credhub/9a2b65b5 | xlarge.mem | 1 | 4 | 5 | – | 59 | 0.00 |
| diego_brain/cfbd72a0 | small | 2 | 20 | 8 | – | 59 | 0.02 |
| diego_cell/05570c4e | xlarge.mem | 2 | 3 | 53 | – | 59 | 0.06 |
| diego_cell/dec53b4d | xlarge.mem | 2 | 3 | 53 | – | 59 | 0.00 |
| diego_database/fabc1d18 | micro | 4 | 40 | 6 | – | 59 | 0.01 |
| doppler/019cc7f8 | small | 4 | 18 | 5 | – | 59 | 0.00 |
| doppler/5ef30ac8 | small | 6 | 20 | 5 | – | 59 | 0.08 |
| log_cache/92770e83 | medium.mem | 5 | 11 | 7 | – | 59 | 0.00 |
| loggregator_trafficcontroller/65b3eca0 | micro | 2 | 36 | 4 | – | 59 | 0.16 |
| mysql/e1248e8c | large.disk | 4 | 18 | 1 | 6 | 59 | 0.20 |
| mysql_monitor/a8b65ffb | micro | 2 | 35 | 3 | – | 59 | 0.00 |
| mysql_proxy/275dc026 | micro | 3 | 35 | 4 | – | 59 | 0.02 |
| nats/4b5c7ff9 | micro | 2 | 36 | 4 | – | 59 | 0.01 |
| nfs_server/009020af | medium | 1 | 12 | 6 | 10 | 59 | 0.00 |
| router/44fc382f | micro.ram | 2 | 39 | 4 | – | 59 | 0.03 |
| uaa/9d69a088 | medium.disk | 4 | 27 | 3 | – | 59 | 0.26 |

- ✅ [cf-6f11f8e43cd7b626077b] clock_global within thresholds (cpu 2% mem 23% eph 20% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] cloud_controller within thresholds (cpu 3% mem 13% eph 23% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] cloud_controller_worker within thresholds (cpu 2% mem 52% eph 10% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] credhub within thresholds (cpu 1% mem 3% eph 5% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] credhub within thresholds (cpu 1% mem 4% eph 5% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] diego_brain within thresholds (cpu 2% mem 20% eph 8% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] diego_cell within thresholds (cpu 2% mem 3% eph 53% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] diego_cell within thresholds (cpu 2% mem 3% eph 53% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] diego_database within thresholds (cpu 4% mem 40% eph 6% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] doppler within thresholds (cpu 4% mem 18% eph 5% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] doppler within thresholds (cpu 6% mem 20% eph 5% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] log_cache within thresholds (cpu 5% mem 11% eph 7% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] loggregator_trafficcontroller within thresholds (cpu 2% mem 36% eph 4% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] mysql within thresholds (cpu 4% mem 18% eph 1% per 6% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] mysql_monitor within thresholds (cpu 2% mem 35% eph 3% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] mysql_proxy within thresholds (cpu 3% mem 35% eph 4% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] nats within thresholds (cpu 2% mem 36% eph 4% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] nfs_server within thresholds (cpu 1% mem 12% eph 6% per 10% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] router within thresholds (cpu 2% mem 39% eph 4% per –% sys 59%)
- ✅ [cf-6f11f8e43cd7b626077b] uaa within thresholds (cpu 4% mem 27% eph 3% per –% sys 59%)

_Thresholds — mem 85/95%, disk 80/90%, cpu 80/95% (WARN/CRIT)._

## 4. Allocated vs Utilized

| Instance | VM Type | RAM used | RAM alloc | Ephem used | Ephem alloc | RAM ratio |
|---|---|--:|--:|--:|--:|--:|
| clock_global/3586f01c | medium.disk | 915 MB | 4.0 GB | 6.4 GB | 32.0 GB | 22% |
| cloud_controller/2d5c0972 | large.disk | 1.1 GB | 8.0 GB | 14.7 GB | 64.0 GB | 14% |
| cloud_controller_worker/2bf613b3 | micro | 506 MB | 1.0 GB | 819 MB | 8.0 GB | 49% |
| credhub/7034e814 | xlarge.mem | 1.1 GB | 32.0 GB | 1.6 GB | 32.0 GB | 3% |
| credhub/9a2b65b5 | xlarge.mem | 1.2 GB | 32.0 GB | 1.6 GB | 32.0 GB | 4% |
| diego_brain/cfbd72a0 | small | 393 MB | 2.0 GB | 655 MB | 8.0 GB | 19% |
| diego_cell/05570c4e | xlarge.mem | 990 MB | 32.0 GB | 17.0 GB | 32.0 GB | 3% |
| diego_cell/dec53b4d | xlarge.mem | 997 MB | 32.0 GB | 17.0 GB | 32.0 GB | 3% |
| diego_database/fabc1d18 | micro | 392 MB | 1.0 GB | 492 MB | 8.0 GB | 38% |
| doppler/019cc7f8 | small | 368 MB | 2.0 GB | 410 MB | 8.0 GB | 18% |
| doppler/5ef30ac8 | small | 402 MB | 2.0 GB | 410 MB | 8.0 GB | 20% |
| log_cache/92770e83 | medium.mem | 890 MB | 8.0 GB | 573 MB | 8.0 GB | 11% |
| loggregator_trafficcontroller/65b3eca0 | micro | 354 MB | 1.0 GB | 328 MB | 8.0 GB | 35% |
| mysql/e1248e8c | large.disk | 1.4 GB | 8.0 GB | 655 MB | 64.0 GB | 18% |
| mysql_monitor/a8b65ffb | micro | 342 MB | 1.0 GB | 246 MB | 8.0 GB | 33% |
| mysql_proxy/275dc026 | micro | 343 MB | 1.0 GB | 328 MB | 8.0 GB | 33% |
| nats/4b5c7ff9 | micro | 354 MB | 1.0 GB | 328 MB | 8.0 GB | 35% |
| nfs_server/009020af | medium | 480 MB | 4.0 GB | 492 MB | 8.0 GB | 12% |
| router/44fc382f | micro.ram | 380 MB | 1.0 GB | 328 MB | 8.0 GB | 37% |
| uaa/9d69a088 | medium.disk | 1.1 GB | 4.0 GB | 983 MB | 32.0 GB | 27% |

- ✅ [cf-6f11f8e43cd7b626077b] clock_global RAM allocation 22% used (915 MB of 4.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] cloud_controller RAM allocation 14% used (1.1 GB of 8.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] cloud_controller_worker RAM allocation 49% used (506 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] credhub RAM allocation 3% used (1.1 GB of 32.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] credhub RAM allocation 4% used (1.2 GB of 32.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] diego_brain RAM allocation 19% used (393 MB of 2.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] diego_cell RAM allocation 3% used (990 MB of 32.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] diego_cell RAM allocation 3% used (997 MB of 32.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] diego_database RAM allocation 38% used (392 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] doppler RAM allocation 18% used (368 MB of 2.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] doppler RAM allocation 20% used (402 MB of 2.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] log_cache RAM allocation 11% used (890 MB of 8.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] loggregator_trafficcontroller RAM allocation 35% used (354 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] mysql RAM allocation 18% used (1.4 GB of 8.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] mysql_monitor RAM allocation 33% used (342 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] mysql_proxy RAM allocation 33% used (343 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] nats RAM allocation 35% used (354 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] nfs_server RAM allocation 12% used (480 MB of 4.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] router RAM allocation 37% used (380 MB of 1.0 GB)
- ✅ [cf-6f11f8e43cd7b626077b] uaa RAM allocation 27% used (1.1 GB of 4.0 GB)

## 5. Diego Cells

**Cells:** 2 · reserved/capacity 0 MB / 62.7 GB (0%) · available 62.7 GB · LRPs: n/a

| Cell | Reserved | Capacity | Available | Containers | Reserved% |
|---|--:|--:|--:|--:|--:|
| 05570c4e | 0 MB | 31.3 GB | 31.3 GB | 0/249 | 0% |
| dec53b4d | 0 MB | 31.3 GB | 31.3 GB | 0/249 | 0% |

- ✅ Available 62.7 GB >= largest cell 31.3 GB — a cell can be drained during a rolling upgrade without exhausting placement capacity.

## 6. Cloud Foundry API

- ✅ CF API reachable: https://api.system.skynetsystems.io (v3.160.0) as admin

_Orgs: 1 · Spaces: 0 · Apps: 0._

## 7. Upgrade Readiness

- ⚠️ Staged change: VMware Tanzu Application Service [cf] — update v6.0.0 → v6.0.0 (deployment 'cf-6f11f8e43cd7b626077b') · 12 errand(s) will run. Apply or revert before upgrading.
- ✅ Stemcells consistent: ubuntu-jammy/1.1193* 
- ⚠️ 2 orphaned persistent disk(s) — review with 'bosh disks --orphaned' / 'bosh clean-up'.
- ✅ No ignored instances — every VM will be updated during the upgrade.

**Stemcells in use:**

| Deployment | Stemcell |
|---|---|
| cf-6f11f8e43cd7b626077b | bosh-vsphere-esxi-ubuntu-jammy-go_agent/1.1193 |

## 8. Certificates

- ✅ No certificates expiring within 1m.

## 9. MySQL / Galera Cluster

- ✅ mysql-diag: Galera cluster healthy on mysql_monitor (0 node(s) reported Synced).

---
_Generated by pcf-health-check.sh — read-only pre-upgrade health check._
