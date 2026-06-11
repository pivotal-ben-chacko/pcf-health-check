# PCF Certificate Rotation Estimate

- **Director:** `192.168.2.2`
- **Generated:** 2026-06-11 03:25:10 UTC
- **Horizon:** all certificates (no expiry limit)
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)

## Summary

| Metric | Value |
|---|---|
| Expiring certs (all (no limit)) | 112 |
| — leaf / CA | 105 / 7 |
| — require Digicert (operator-supplied) | 2 |
| Live VMs | 7 |
| One foundation-wide Apply | 48m – 1h 30m |
| **Estimated rotation time** | **2h 24m – 4h 30m** |

## Expiring certificates (within all (no limit))

<table>
<colgroup><col style="width:60%"><col style="width:15%"><col style="width:25%"></colgroup>
<thead><tr><th>Certificate</th><th>Type</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>/services/tls_leaf</code></td><td>Leaf</td><td style="white-space:nowrap">2027-05-30T16:32:48Z</td></tr>
<tr><td><code>/bosh_dns_health_client_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2027-05-30T16:32:51Z</td></tr>
<tr><td><code>/bosh_dns_health_server_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2027-05-30T16:32:51Z</td></tr>
<tr><td><code>/dns_api_client_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2027-05-30T16:32:51Z</td></tr>
<tr><td><code>/dns_api_server_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2027-05-30T16:32:51Z</td></tr>
<tr><td><code>.director.system_metrics_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:30Z</td></tr>
<tr><td><code>.properties.credhub_ssl</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:31Z</td></tr>
<tr><td><code>.properties.director_agent_ssl</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:31Z</td></tr>
<tr><td><code>.properties.director_ssl</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:31Z</td></tr>
<tr><td><code>.properties.uaa_ssl</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:31Z</td></tr>
<tr><td><code>.properties.blobstore_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:32Z</td></tr>
<tr><td><code>.properties.director_metrics_server_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:32Z</td></tr>
<tr><td><code>.properties.director_metrics_server_client_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:32Z</td></tr>
<tr><td><code>.properties.nats_director_client_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:33Z</td></tr>
<tr><td><code>.properties.nats_health_monitor_client_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:33Z</td></tr>
<tr><td><code>.properties.nats_server_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-05-29T03:16:33Z</td></tr>
<tr><td><code>.properties.networking_poe_ssl_certs[0].certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:14:31Z</td></tr>
<tr><td><code>.uaa.service_provider_key_credentials</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:15:13Z</td></tr>
<tr><td><code>.properties.auctioneer_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:51Z</td></tr>
<tr><td><code>.properties.auctioneer_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:52Z</td></tr>
<tr><td><code>.properties.bbs_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:52Z</td></tr>
<tr><td><code>.properties.bbs_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:52Z</td></tr>
<tr><td><code>.properties.cloud_controller_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:53Z</td></tr>
<tr><td><code>.properties.cloud_controller_logcache_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:53Z</td></tr>
<tr><td><code>.properties.cloud_controller_mutual_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:54Z</td></tr>
<tr><td><code>.properties.cloud_controller_public_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:54Z</td></tr>
<tr><td><code>.properties.credhub_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:54Z</td></tr>
<tr><td><code>.properties.file_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:54Z</td></tr>
<tr><td><code>.properties.log_cache_auth_proxy_client_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:55Z</td></tr>
<tr><td><code>.properties.log_cache_server_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:55Z</td></tr>
<tr><td><code>.properties.log_cache_cf_auth_proxy_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:56Z</td></tr>
<tr><td><code>.properties.log_cache_gateway_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:56Z</td></tr>
<tr><td><code>.properties.log_cache_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:56Z</td></tr>
<tr><td><code>.properties.forwarder_agent_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:57Z</td></tr>
<tr><td><code>.properties.log_cache_syslog_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:57Z</td></tr>
<tr><td><code>.properties.log_cache_syslog_server_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:57Z</td></tr>
<tr><td><code>.properties.log_cache_gateway_auth_proxy_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:58Z</td></tr>
<tr><td><code>.properties.loggregator_agent_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:58Z</td></tr>
<tr><td><code>.properties.loggr_syslog_binding_cache_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:58Z</td></tr>
<tr><td><code>.properties.loggr_udp_forwarder_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:58Z</td></tr>
<tr><td><code>.properties.leadership_election_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:59Z</td></tr>
<tr><td><code>.properties.loggr_metric_scraper_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:17:59Z</td></tr>
<tr><td><code>.properties.leadership_election_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:00Z</td></tr>
<tr><td><code>.properties.loggregator_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:00Z</td></tr>
<tr><td><code>.properties.metric_registrar_orchestrator_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:00Z</td></tr>
<tr><td><code>.properties.metric_registrar_rlp_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:00Z</td></tr>
<tr><td><code>.properties.metric_registrar_endpoint_worker_scrape_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:01Z</td></tr>
<tr><td><code>.properties.metric_registrar_secure_worker_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:01Z</td></tr>
<tr><td><code>.properties.metric_registrar_worker_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:01Z</td></tr>
<tr><td><code>.properties.metric_registrar_binding_cache_mtls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:02Z</td></tr>
<tr><td><code>.properties.otel_collector_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:02Z</td></tr>
<tr><td><code>.properties.cf_hub_collector_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:03Z</td></tr>
<tr><td><code>.properties.nats_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:03Z</td></tr>
<tr><td><code>.properties.nats_tls_external_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:04Z</td></tr>
<tr><td><code>.properties.nats_tls_internal_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:04Z</td></tr>
<tr><td><code>.properties.network_policy_agent_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:04Z</td></tr>
<tr><td><code>.properties.network_policy_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:05Z</td></tr>
<tr><td><code>.properties.network_policy_server_external_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:06Z</td></tr>
<tr><td><code>.properties.prom_scraper_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:06Z</td></tr>
<tr><td><code>.properties.prom_scraper_scrape_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:06Z</td></tr>
<tr><td><code>.properties.pxc_internal_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:06Z</td></tr>
<tr><td><code>.properties.mysql_diag_agent_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:07Z</td></tr>
<tr><td><code>.properties.mysql_galera_agent_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:07Z</td></tr>
<tr><td><code>.properties.mysql_proxy_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:07Z</td></tr>
<tr><td><code>.properties.pxc_server_certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:07Z</td></tr>
<tr><td><code>.properties.mysql_replication_canary_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:08Z</td></tr>
<tr><td><code>.properties.rep_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:08Z</td></tr>
<tr><td><code>.properties.rep_server_cert_v2</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:08Z</td></tr>
<tr><td><code>.properties.reverse_log_proxy_gateway_client_tls_cc_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:09Z</td></tr>
<tr><td><code>.properties.reverse_log_proxy_gateway_server_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:09Z</td></tr>
<tr><td><code>.properties.reverse_log_proxy_gateway_client_tls_rlp_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:10Z</td></tr>
<tr><td><code>.properties.rlp_gateway_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:10Z</td></tr>
<tr><td><code>.properties.routing_api_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:10Z</td></tr>
<tr><td><code>.properties.routing_api_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:11Z</td></tr>
<tr><td><code>.properties.routing_backends_client_cert_with_san</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:11Z</td></tr>
<tr><td><code>.properties.routing_lb_health_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:11Z</td></tr>
<tr><td><code>.properties.service_discovery_client_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:11Z</td></tr>
<tr><td><code>.properties.service_discovery_server_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:12Z</td></tr>
<tr><td><code>.properties.ssh_proxy_backends_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:12Z</td></tr>
<tr><td><code>.properties.syslog_agent_log_cache_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:12Z</td></tr>
<tr><td><code>.properties.syslog_agent_metrics_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:12Z</td></tr>
<tr><td><code>.properties.system_blobstore_public_endpoint_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:12Z</td></tr>
<tr><td><code>.properties.tcp_routing_lb_health_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:13Z</td></tr>
<tr><td><code>.properties.tps_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:13Z</td></tr>
<tr><td><code>.properties.syslog_agent_api_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:14Z</td></tr>
<tr><td><code>.properties.system_metrics_tls_scraper_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:14Z</td></tr>
<tr><td><code>.properties.trafficcontroller_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:14Z</td></tr>
<tr><td><code>.properties.binding_cache_api_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:15Z</td></tr>
<tr><td><code>.properties.policy_server_asg_syncer</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:15Z</td></tr>
<tr><td><code>.nfs_server.blobstore_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:16Z</td></tr>
<tr><td><code>.properties.cloud_controller_prom_scraper_scrape_tls</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:16Z</td></tr>
<tr><td><code>.properties.policy_server_asg_syncer_cc_client</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:16Z</td></tr>
<tr><td><code>.diego_database.locket_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:17Z</td></tr>
<tr><td><code>.diego_database.silk_controller_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:17Z</td></tr>
<tr><td><code>.diego_database.silk_daemon_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:17Z</td></tr>
<tr><td><code>.cloud_controller.locket_client_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:18Z</td></tr>
<tr><td><code>.uaa.ssl_credentials</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:18Z</td></tr>
<tr><td><code>.diego_brain.cc_uploader_server_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:19Z</td></tr>
<tr><td><code>.loggregator_trafficcontroller.cc_trafficcontroller_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:19Z</td></tr>
<tr><td><code>.loggregator_trafficcontroller.rlp_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:20Z</td></tr>
<tr><td><code>.loggregator_trafficcontroller.statsdinjector_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:20Z</td></tr>
<tr><td><code>.loggregator_trafficcontroller.trafficcontroller_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:20Z</td></tr>
<tr><td><code>.doppler.doppler_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:21Z</td></tr>
<tr><td><code>.doppler.metron_tls_cert</code></td><td>Leaf</td><td style="white-space:nowrap">2028-06-09T04:18:21Z</td></tr>
<tr><td><code>/p-bosh/cf-dbe1a7580979a87638e7/diego-instance-identity-intermediate-ca-2-7</code></td><td>CA</td><td style="white-space:nowrap">2028-06-09T04:19:47Z</td></tr>
<tr><td><code>/cf/diego-instance-identity-root-ca-2-6</code></td><td>CA</td><td style="white-space:nowrap">2029-05-29T16:32:45Z</td></tr>
<tr><td><code>opsman-root-ca:3506e333</code></td><td>CA</td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
<tr><td><code>.properties.nats_client_ca.3506e33356bef86af963</code></td><td>CA</td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
<tr><td><code>.properties.root_ca.3506e33356bef86af963</code></td><td>CA</td><td style="white-space:nowrap">2030-05-29T03:06:57Z</td></tr>
<tr><td><code>/opsmgr/bosh_dns/tls_ca</code></td><td>CA</td><td style="white-space:nowrap">2030-05-29T16:32:50Z</td></tr>
<tr><td><code>/opsmgr/bosh_dns/san_migrated</code></td><td>Leaf</td><td style="white-space:nowrap">2030-05-29T16:32:52Z</td></tr>
<tr><td><code>/services/tls_ca</code></td><td>CA</td><td style="white-space:nowrap">2031-05-29T03:24:34Z</td></tr>
</tbody>
</table>

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
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation + 1 deployment applies; a BOSH trusted-store CA = 1 foundation-wide apply (swap in place); a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
