# PCF lab Certificate Rotation Estimate

- **Director:** `192.168.2.2`
- **Generated:** 2026-06-10 11:20:56 UTC
- **Horizon:** all certificates (no expiry limit)
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)

## Summary

| Metric | Value |
|---|---|
| Expiring certs (all (no limit)) | 112 (❌ 0 · ⚠️ 0) |
| — leaf / CA | 105 / 7 |
| Live VMs (DB nodes) | 7 (2) |
| One foundation-wide Apply | 1h 00m – 1h 50m |
| **Estimated rotation time** | **3h 00m – 5h 30m** |

## Foundation inventory

| Deployment | Type | VMs | Est. cert-rotation time |
|---|---|---:|---|
| `cf-dbe1a7580979a87638e7` | cf | 7 | 3h 00m – 5h 30m |

> 2 instance group(s) have `serial:false` — they may update in parallel, so real time can come in under the (conservative serial) estimate.

## CA rotations (3-phase)

<table>
<colgroup><col style="width:82%"><col style="width:18%"></colgroup>
<thead><tr><th>Certificate</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.properties.nats_client_ca.3506e33356bef86af963</code></td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
<tr><td><code>.properties.root_ca.3506e33356bef86af963</code></td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
<tr><td><code>/p-bosh/cf-dbe1a7580979a87638e7/diego-instance-identity-intermediate-ca-2-7</code></td><td style="white-space:nowrap">2028-06-09T04:19:47Z</td></tr>
<tr><td><code>/opsmgr/bosh_dns/tls_ca</code></td><td style="white-space:nowrap">2030-05-29T16:32:50Z</td></tr>
<tr><td><code>/cf/diego-instance-identity-root-ca-2-6</code></td><td style="white-space:nowrap">2029-05-29T16:32:45Z</td></tr>
<tr><td><code>/services/tls_ca</code></td><td style="white-space:nowrap">2031-05-29T03:24:34Z</td></tr>
<tr><td><code>opsman-root-ca:3506e333</code></td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
</tbody>
</table>

## Leaf certificates

| Deployment | Leaf certs |
|---|---:|
| `p-bosh (not VM-counted)` | 11 |
| `cf-dbe1a7580979a87638e7` | 94 |

## Estimate breakdown

| Campaign | Applies | Time (low – high) |
|---|---|---|
| Leaf certs | folded into the shared apply #2 | included |
| CA certs (full batch) | 3× foundation-wide on all tiles — all CAs + leaves | 3h 00m – 5h 30m |
| **Total** | | **3h 00m – 5h 30m** |

## Model & assumptions

- 20m overhead per Apply Changes; stateless 4–10m/VM, DB 10–20m/node.
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation + 1 deployment applies; a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
