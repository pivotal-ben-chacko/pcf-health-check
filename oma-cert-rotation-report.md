# PCF OMA Certificate Rotation Estimate

- **Director:** `director.system.us-oma1-ip01.1dc.com`
- **Generated:** 2026-06-11 15:48:58 UTC
- **Horizon:** certificates expiring within `45d`
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)

## Summary

| Metric | Value |
|---|---|
| Expiring certs (45d) | 6 |
| — leaf / CA | 4 / 2 |
| — require Digicert (operator-supplied) | 5 |
| Live VMs | 558 |
| One foundation-wide Apply | 24h 04m – 59h 40m |
| **Estimated rotation time** | **61h 12m – 151h 30m** |

## Expiring certificates (within 45d)

<table>
<colgroup><col style="width:60%"><col style="width:15%"><col style="width:25%"></colgroup>
<thead><tr><th>Certificate</th><th>Type</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.security_configuration.trusted_certificates[1]</code></td><td>CA</td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>/services/tls_ca</code></td><td>CA</td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>.properties.routing_custom_ca_certificates</code></td><td>Leaf</td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>.properties.grafana_route.manual.ssl_certificates</code></td><td>Leaf</td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
<tr><td><code>.properties.networking_poe_ssl_certs[0].certificate</code></td><td>Leaf</td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
<tr><td><code>.uaa.service_provider_key_credentials</code></td><td>Leaf</td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
</tbody>
</table>

## Foundation inventory

<table>
<colgroup><col style="width:72%"><col style="width:8%"><col style="width:20%"></colgroup>
<thead><tr><th>Deployment</th><th style="text-align:right">VMs</th><th>Est. cert-rotation time</th></tr></thead>
<tbody>
<tr><td><code>bosh-health</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
<tr><td><code>cf-faf3d38a0032988a4dc2</code></td><td style="text-align:right">364</td><td style="white-space:nowrap">22h 40m – 55h 40m</td></tr>
<tr><td><code>concourse</code></td><td style="text-align:right">8</td><td style="white-space:nowrap">2h 00m – 3h 30m</td></tr>
<tr><td><code>credhub-service-broker-d6dda5dfb801bd617e5d</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
<tr><td><code>extended-app-support-da9f163d9405adf5d192</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
<tr><td><code>harbor-container-registry-c4b61c69a19955916d7f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>p-cloudcache-98c58950d6925e64a679</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>p-dataflow-125ca90e19279a2edeee</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
<tr><td><code>p-healthwatch2-e6fa153a2da23c59222b</code></td><td style="text-align:right">5</td><td style="white-space:nowrap">2h 00m – 3h 30m</td></tr>
<tr><td><code>p-healthwatch2-pas-exporter-292975fcf76753210a77</code></td><td style="text-align:right">6</td><td style="white-space:nowrap">2h 12m – 4h 00m</td></tr>
<tr><td><code>p-rabbitmq-2acecb12424a9ab3017e</code></td><td style="text-align:right">8</td><td style="white-space:nowrap">2h 36m – 5h 00m</td></tr>
<tr><td><code>p-redis-6aa37b73897373e506fc</code></td><td style="text-align:right">2</td><td style="white-space:nowrap">1h 24m – 2h 00m</td></tr>
<tr><td><code>p-scheduler-7d6f2ac189cd5e84ca38</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
<tr><td><code>p_spring-cloud-services-e2badae5f49a4996028d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>pivotal-mysql-0a15a66ea04fe4b1c068</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_002b04a2-4ca5-420a-9667-5fdb9b399202</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_00701107-3f30-4026-a601-6277a9dfdd89</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_0765138b-2fd9-4a82-b074-bfd61962f4a5</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_0c17c9c8-8a45-4a43-8488-5df2ae6766d0</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_0c26ca30-5052-4882-9199-ccd31991a297</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_0d1d7288-5eb3-45d9-ad37-5b3c5fb4c4e4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_0fbad95c-6ab5-4cf6-b183-41fe337606f4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_11d60078-cb0f-479e-9188-e50ef9ff22f6</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_172647f7-9e24-4b20-a753-6d250a723e18</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_1c18514c-29da-4bf6-b411-9a8ec46e40b5</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_24549035-060a-4fbe-98a2-4f5eede81677</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_308a28fb-8c0e-4600-b749-23734089b5a4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_34efcaba-12fe-403f-98a9-4a4237cd14ca</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_37bc0a0e-58a4-450b-a61d-87674a4bd2da</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_3c09518b-b4f8-4871-98e1-44c9bc30dbdd</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_3cd7d601-162d-4945-9ac0-27aeccf3d4d1</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_3f8bf9cb-2b6b-4c53-8073-f20e6f1d4c90</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_414ca893-7848-4b0c-8970-f1a8ed54d34d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_450e2c74-41ba-4138-8d3b-2e46fc2592ac</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_45b7b068-c9d3-4026-b92e-0adfb1317e8d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_48bb6ad1-d4fb-4639-b0cb-ce3f3b02d41f</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_4ae7f005-9984-409e-9ffe-9654d0529778</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_4b523c4a-0b5b-43f0-ab25-98c5fe98af49</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_4d8b0d8c-47d6-4b52-9791-d57e257c592a</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_51c2f2e0-95eb-47a6-87ce-706863d3cf2c</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_592dc708-f14c-40b0-ae72-e0bbcdaa3092</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_594585f6-04f7-410a-9c71-854b2bce858a</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_595b3ddf-b97c-4383-b594-8b02b181b731</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_5d721de9-672f-4290-80a3-fb7e2848895f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_62dc3174-d3b5-4e73-a888-f7197f26c90d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_63491f53-7718-4ed9-a527-6ac1dfa896f5</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_64ada1f3-a65b-47f5-a600-2bcd1820a84f</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_69577dd1-5f4d-4c2d-b300-04181669f343</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_6a9a87d3-ad7a-4110-b83a-ebca278b5959</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_73d37a4f-aa34-4ea3-8351-7b7d4fb68c11</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_76ac83f3-e469-4936-a096-8ff41583f579</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_78cf74eb-c5a6-4227-9660-0cf77c2e2505</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_78f85243-8065-4f66-81d2-3ea1a92e7b83</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_7dbd9e6e-b5a8-4a4c-8ae7-458bb9e013a1</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_828c9fc5-b338-4342-a4fc-f5cca04392cb</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_8503f39b-c92c-4cdb-adfe-da3b9722cfbc</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_895b2e8c-9d07-490f-b6df-6298956a5d54</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_8ecb75d5-5461-4730-af46-593b8f82d222</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9374ad16-f9ed-4d8e-a4bc-9d53837a166f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_96497f76-598f-4179-acab-af45ccc1b9ec</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_9668a334-158e-4e4e-bfe4-a1f44e887618</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9737a61a-0e51-4b51-a3bb-78d1559637e3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9997220d-79c7-4b6e-837d-5283afa005fa</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9ab55cdb-d716-4e2b-be8e-28ee74def27e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9b7096b3-51e6-4b31-93f4-626a23973b96</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9dc11c06-38b6-450c-8b90-d7426edcd5c8</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_9f093d24-305e-41c9-81ce-1555293b0a02</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_a05438f6-3500-4885-9a22-8eb35d32304c</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_a09bcc4e-0f80-4875-9020-194c179cacbc</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_a3275dcf-c439-48a0-b6e8-c73df3323883</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_a32c7fe4-8449-4f7a-9bb1-600f1f10a04f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_a40e5a7b-0927-4ca6-9c11-9508c4e31a5c</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_a5ab5021-8a81-4157-891f-fbc4a0a46456</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_a75d8b6a-f20a-4ed5-9ab3-fdd012b3207a</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_a7fe8467-52f5-4012-af37-49d863c9289e</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_a9529d64-de28-43f1-afe9-04f4fe2bded5</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_aaffe13b-66de-4467-972a-f4031cb3e3bb</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_ab4453c7-7deb-4eb7-b505-ae0626bb9a7a</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_ace8507a-7621-49ed-acf1-73384b014240</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_b00c56c3-360e-4639-a9b2-d4b017c1d6e4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_b071444d-8bfa-40e1-98e7-3cb110c86587</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_b63e42f7-5285-4a1c-981d-91dbb5b1558c</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_bc0f4809-362d-4850-8442-f81ad14602ed</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_bc93509d-db99-42b7-ac9d-eea2ac553461</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_bd535a83-d036-40b2-a193-df954756f84f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_c1c55568-561c-4f69-9812-ee4981b16872</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_c3250627-322e-4c9e-a3c6-d232483ffbbe</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_c9d50845-c97b-4a1d-a534-2c19a33cb9be</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_cc847b24-778a-4357-8c43-7c7c2939c0d2</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_ce7054c9-6b69-4afd-822e-785afc12d014</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">2h 24m – 4h 30m</td></tr>
<tr><td><code>service-instance_cfba7d35-22b8-44b1-a6cd-21086f6afcbe</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_d15636dd-2122-40c0-919d-8c3404a8cafc</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_d568f76c-659e-47a6-9420-2fe2f21caec8</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_d583b5e8-3217-43a3-867f-7d183cbeb07e</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_d8d7f337-14d7-40f1-912c-cb2c4a802ce0</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_de5984f3-8abd-4520-94dc-dda19d03baa1</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_dff2dd27-3f95-4fbb-bc37-d5fa8b452c0e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_e0a79733-819a-40f8-a724-1781d5cf3184</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_e16fbd95-2724-4783-8e40-8a3e279fd593</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_e24a901f-2224-491c-920d-c3fcbe855c0d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_f0a0be5d-2d51-471f-9c0e-d5e3a753c16b</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_f1a9a139-403f-414b-a6bc-b38c8e2fa4ac</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_f274b754-4565-4b6b-901b-598661f9a5ca</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">1h 12m – 1h 30m</td></tr>
<tr><td><code>service-instance_f47fe238-5b2a-4022-a95b-a46046aa2b8a</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_f98ef59b-17cb-41ad-9b0b-74e89602c9fc</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>service-instance_fcbf2070-568d-40bd-a70a-e8cc12fb9a0b</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">1h 36m – 2h 30m</td></tr>
<tr><td><code>splunk-nozzle-a5a273f9875e8bb88782</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">1h 00m – 1h 00m</td></tr>
</tbody>
</table>

> 18 instance group(s) have `serial:false` — they may update in parallel, so real time can come in under the (conservative serial) estimate.

## CA rotations

<table>
<colgroup><col style="width:54%"><col style="width:28%"><col style="width:18%"></colgroup>
<thead><tr><th>Certificate</th><th>Rotation</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.security_configuration.trusted_certificates[1]</code></td><td>1× foundation-wide</td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>/services/tls_ca</code></td><td>2× foundation + 1× all-but-cf</td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
</tbody>
</table>

## Leaf certificates

| Deployment | Leaf certs |
|---|---:|
| `cf-faf3d38a0032988a4dc2` | 3 |
| `p-healthwatch2-e6fa153a2da23c59222b` | 1 |

## Operator-supplied certificates — require Digicert

> Not auto-generated. A new certificate must be obtained from Digicert before rotation (out-of-band; not included in the Apply Changes time above).

<table>
<colgroup><col style="width:82%"><col style="width:18%"></colgroup>
<thead><tr><th>Certificate</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.security_configuration.trusted_certificates[1]</code></td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>.properties.grafana_route.manual.ssl_certificates</code></td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
<tr><td><code>.properties.networking_poe_ssl_certs[0].certificate</code></td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
<tr><td><code>.properties.routing_custom_ca_certificates</code></td><td style="white-space:nowrap">2026-07-11T06:24:57Z</td></tr>
<tr><td><code>.uaa.service_provider_key_credentials</code></td><td style="white-space:nowrap">2026-07-14T04:01:24Z</td></tr>
</tbody>
</table>

## Estimate breakdown

| Campaign | Applies | Time (low – high) |
|---|---|---|
| Leaf certs | folded into the shared apply #2 | included |
| CA certs (full batch) | 2× foundation-wide on all tiles + 1× all tiles except cf (services TLS CA leaf regen) — all CAs + leaves | 61h 12m – 151h 30m |
| **Total** | | **61h 12m – 151h 30m** |

## Model & assumptions

- 20m overhead per Apply Changes; 4–10m per VM.
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation-wide applies (propagate new CA, delete old CA) + 1 apply over every tile EXCEPT cf (regenerate its leaf certs); a BOSH trusted-store CA = 1 foundation-wide apply (swap in place); a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
