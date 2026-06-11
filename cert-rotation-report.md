# PCF Certificate Rotation Estimate

- **Director:** `192.168.2.2`
- **Generated:** 2026-06-11 02:13:57 UTC
- **Horizon:** all certificates (no expiry limit)
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)

## Summary

| Metric | Value |
|---|---|
| Expiring certs (all (no limit)) | 112 (❌ 0 · ⚠️ 0) |
| — leaf / CA | 105 / 7 |
| — require Digicert (operator-supplied) | 2 |
| Live VMs | 7 |
| One foundation-wide Apply | 48m – 1h 30m |
| **Estimated rotation time** | **2h 24m – 4h 30m** |

## Foundation inventory

<table>
<colgroup><col style="width:72%"><col style="width:8%"><col style="width:20%"></colgroup>
<thead><tr><th>Deployment</th><th style="text-align:right">VMs</th><th>Est. cert-rotation time</th></tr></thead>
<tbody>
<tr><td><code>cf-dbe1a7580979a87638e7</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
</tbody>
</table>

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

## Operator-supplied certificates — require Digicert

> Not auto-generated. A new certificate must be obtained from Digicert before rotation (out-of-band; not included in the Apply Changes time above).

<table>
<colgroup><col style="width:82%"><col style="width:18%"></colgroup>
<thead><tr><th>Certificate</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.properties.networking_poe_ssl_certs[0].certificate</code></td><td style="white-space:nowrap">2028-06-09T04:14:31Z</td></tr>
<tr><td><code>.uaa.service_provider_key_credentials</code></td><td style="white-space:nowrap">2028-06-09T04:15:13Z</td></tr>
</tbody>
</table>

## Estimate breakdown

| Campaign | Applies | Time (low – high) |
|---|---|---|
| Leaf certs | folded into the shared apply #2 | included |
| CA certs (full batch) | 3× foundation-wide on all tiles — all CAs + leaves | 2h 24m – 4h 30m |
| **Total** | | **2h 24m – 4h 30m** |

## Model & assumptions

- 20m overhead per Apply Changes; 4–10m per VM.
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation + 1 deployment applies; a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
