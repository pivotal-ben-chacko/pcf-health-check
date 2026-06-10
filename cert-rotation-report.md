# PCF lab Certificate Rotation Estimate

- **Director:** `192.168.2.2`
- **Generated:** 2026-06-10 10:13:00 UTC
- **Horizon:** certificates expiring within `5y`
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)

## Summary

| Metric | Value |
|---|---|
| Expiring certs (≤ 5y) | 112 (❌ 0 · ⚠️ 0) |
| — leaf / CA | 105 / 7 |
| Live VMs (DB nodes) | 7 (2) |
| One foundation-wide Apply | 1h 00m – 1h 50m |
| **Estimated rotation time** | **11h 00m – 20h 10m** |

## Foundation inventory

| Deployment | Type | VMs | DB nodes |
|---|---|---:|---:|
| `cf-dbe1a7580979a87638e7` | cf | 7 | 2 |

> 2 instance group(s) have `serial:false` — they may update in parallel, so real time can come in under the (conservative serial) estimate.

## CA rotations (3-phase)

| CA | Scope model | Apply plan | Expires | Severity |
|---|---|---|---|---|
| `.properties.nats_client_ca.3506e33356bef86af963` | FOUNDATION | 3x foundation-wide | 2030-05-29T03:06:57Z | ℹ️ info |
| `.properties.root_ca.3506e33356bef86af963` | FOUNDATION | 3x foundation-wide | 2030-05-29T03:06:57Z | ℹ️ info |
| `/p-bosh/cf-dbe1a7580979a87638e7/diego-instance-identity-intermediate-ca-2-7` | DEPLOYMENT | 3x cf-dbe1a7580979a87638e7 | 2028-06-09T04:19:47Z | ℹ️ info |
| `/opsmgr/bosh_dns/tls_ca` | FOUNDATION | 3x foundation-wide | 2030-05-29T16:32:50Z | ℹ️ info |
| `/cf/diego-instance-identity-root-ca-2-6` | DEPLOYMENT | 3x cf-dbe1a7580979a87638e7 | 2029-05-29T16:32:45Z | ℹ️ info |
| `/services/tls_ca` | TRUSTED | 2x foundation-wide (BOSH trusted-certs add+remove) + 1x cf-dbe1a7580979a87638e7 | 2031-05-29T03:24:34Z | ℹ️ info |
| `opsman-root-ca:3506e333` | FOUNDATION | 3x foundation-wide | 2030-05-29T03:06:57Z | ℹ️ info |

## Leaf certificates (1-phase)

| Deployment | Leaf certs | Apply |
|---|---:|---|
| `p-bosh (not VM-counted)` | 11 | 1× (with the leaf campaign) |
| `cf-dbe1a7580979a87638e7` | 94 | 1× (with the leaf campaign) |

## Estimate breakdown

| Campaign | Applies | Time (low – high) |
|---|---|---|
| Leaf certs | 1× over 2 deployment(s) | 1h 00m – 1h 50m |
| CA certs (batched) | 3× foundation-wide + per-deployment leaf-regen | 10h 00m – 18h 20m |
| **Total** | | **11h 00m – 20h 10m** |

## Model & assumptions

- 20m overhead per Apply Changes; stateless 4–10m/VM, DB 10–20m/node.
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation + 1 deployment applies; a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
