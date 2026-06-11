# PCF CHD Certificate Rotation Estimate


- **Director:** `director.system.us-chd1-ip01.1dc.com`
- **Generated:** 2026-06-10 14:20:14 UTC
- **Horizon:** certificates expiring within `45d`
- **Topology source:** `maestro tp`
- **Update rules:** `bosh manifest` (per-IG max_in_flight/canaries)


## Summary


| Metric | Value |
|---|---|
| Expiring certs (45d) | 3 |
| — leaf / CA | 3 / 0 |
| — require Digicert (operator-supplied) | 3 |
| Live VMs | 514 |
| One foundation-wide Apply | 21h 44m – 53h 50m |
| **Estimated rotation time** | **9h 28m – 23h 10m** |


## Foundation inventory


<table>
<colgroup><col style="width:72%"><col style="width:8%"><col style="width:20%"></colgroup>
<thead><tr><th>Deployment</th><th style="text-align:right">VMs</th><th>Est. cert-rotation time</th></tr></thead>
<tbody>
<tr><td><code>cf-dc3632d155115f0c159e</code></td><td style="text-align:right">319</td><td style="white-space:nowrap">9h 08m – 22h 20m</td></tr>
<tr><td><code>credhub-service-broker-cffdfaea3f31a4c07152</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">20m – 20m</td></tr>
<tr><td><code>harbor-container-registry-ac254f8249adfc467699</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>p-cloudcache-838361f5e7dafc1ea41e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>p-dataflow-a267a54956ee93f17b7d</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">20m – 20m</td></tr>
<tr><td><code>p-healthwatch2-d148bff36cba2d1c7de3</code></td><td style="text-align:right">5</td><td style="white-space:nowrap">40m – 1h 10m</td></tr>
<tr><td><code>p-healthwatch2-pas-exporter-bda9b23631c1a19ef7d5</code></td><td style="text-align:right">6</td><td style="white-space:nowrap">44m – 1h 20m</td></tr>
<tr><td><code>p-rabbitmq-f9a75ced60d64090920f</code></td><td style="text-align:right">9</td><td style="white-space:nowrap">56m – 1h 50m</td></tr>
<tr><td><code>p-redis-c518db3812a40c7daa9c</code></td><td style="text-align:right">2</td><td style="white-space:nowrap">28m – 40m</td></tr>
<tr><td><code>p-scheduler-3c83b7c0f3d5b6f15495</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">20m – 20m</td></tr>
<tr><td><code>p_spring-cloud-services-6735243083a03eaf3d92</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>pivotal-mysql-e91d0bbc59118e6b7ab4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_031bea9c-938b-45ea-833e-acad108b4d1b</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>service-instance_07593f2f-4b46-4812-a45b-ff8485f1dc64</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_09a22e83-bc62-4f21-9ba0-e252836fa8e0</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_0cee5c7d-14db-4f9a-a776-637943e100dc</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_0d7d1435-7db6-4b23-ba0d-033b99104afc</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_0db45f97-1404-494e-b819-29f87ea1aa2e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_0de704f2-81a4-4b1a-ad5d-ee423feeb3da</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_107722b0-a6a6-4da9-9daf-40a2e7738c63</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_110bea5c-6003-4fd8-983e-f6451584028a</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_11bf730a-2256-4c33-80a6-ad9987cd0863</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_1264c0e9-5be3-4118-a3a3-cf88a817c55b</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_14065490-da53-451e-8479-6beb3277a3d0</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_1c9eb324-5df7-4131-8a7d-3a6cc7691a60</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_1e943af4-3203-49a7-bbae-db504ff2b474</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_1f1a2d91-8601-4b57-98d8-8722a4103a83</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_1fd78d80-3561-432d-8c3a-6d163a785d67</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_24545c4a-8f62-4f2d-b433-75975447fd4c</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_253cae47-1262-4736-b607-331693bc33e8</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_2b0e6457-8ee3-4f7d-8445-ac892663d13b</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_2d7f7cb5-5d1b-43b1-96ef-a29f710e3a83</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_2e3db66d-1150-4dcf-a737-a5f3b2f074e6</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_35152954-eb98-442b-ba51-bc6eca176f87</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_36ea8f9e-8480-4180-94c4-911bb6c132c3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_3f2279e7-3a92-4678-a21f-91b9b1bb8b14</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_4b92bc7d-454f-4d3f-bca4-800550f8546a</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_4bada228-8b26-47ad-ae2f-6929b40c0e4e</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">36m – 1h 00m</td></tr>
<tr><td><code>service-instance_5009632e-ab74-4ddb-85ba-a21ca9e15559</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_5065fbf0-f83c-40cc-bef5-d2c46b9e2690</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_52b8496f-322b-4b34-a7c7-b65811942fc2</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_52f3a205-5794-4837-84a3-7de8582b2cfe</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_567f196f-6c5a-47ac-8695-d8c4fc0bf5e8</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_5693165a-820b-4cf1-808f-c0e48bd75d6d</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_5a0f4031-4ed0-4cd0-9b52-60075deeaaab</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_5c531b8b-130e-4e2a-aa65-ba5229841760</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_61daa7e8-1df9-44f2-a4ca-476d07ca4da3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_67887d09-6674-4f6d-b075-0dfb93e8b3e0</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_6901fd54-b75c-4e82-bebe-7eea6c33318b</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_6c132a47-8e78-4e46-9f89-49460a69eee3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_70bc531a-78e7-4fa1-a8ca-131b0821e3f6</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_71990b92-0be2-476f-9c12-934f9e4308b3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_73a6ba38-b983-40af-bd5d-774b2814abce</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_75e8fb03-1312-4b88-93f6-a17678d0e498</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>service-instance_769e84d0-48dc-47e9-b18e-825a11c16658</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_782e906d-e84a-46ab-b76b-edc82a72097c</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_783beedd-ea9a-4405-9c77-0b88b58ab8b5</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_798fbe92-4a11-4b23-8f15-3950de4f96d0</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_79f4cef9-9124-4fad-92f3-4f791f471809</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_7bfc31f6-e2f6-4acc-ae45-1394a096092f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_7fa53aad-3167-4f9e-8aa4-7ed5edd05331</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_81e2ad9f-6763-4709-a16e-f0d163335bf4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_8467f323-4690-4aac-a561-346eda0acdfe</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_852b84ac-e30d-4247-ba05-df03ff3f4f9f</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_8594fce8-b21d-4be5-be81-2358a72d9487</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_883b0af2-ed2f-4685-9bc2-82502910d87e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_8b715b93-67e5-4f58-a088-f94ae8b7d9c4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_8d220f9e-e9da-4772-84d2-d417cc4a3366</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_9b8d3f78-e3a1-426d-a39d-9f8b4df501e8</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_9e2c28bb-0e93-438f-b0d9-5871962e0747</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>service-instance_9f720f00-0455-474d-8d88-4c385f66055e</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>service-instance_a196fcc6-0d87-4f81-b9f2-c9d2acc28ce4</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_a3b674d6-c419-4f9b-a8ff-c717899d3710</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_aa7ddac5-06c4-44bf-9a95-3c1b058e8224</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_ab403812-0aee-48a7-a887-8551efa71d42</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_acf4ee21-3977-4df0-abf1-ff5f3ff05a10</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_adb009c4-37f1-4a26-b3d7-b5265dc0d365</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_b039eaac-0862-49e2-914a-5fd88a94486e</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_b0e6cbf7-26bb-40af-9e16-98f8e0aea2b3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_b0e918b7-b74d-4702-a5d9-628466894c02</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_b2199f57-9812-42be-9aec-8728278d08f3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_b604bb19-b9d0-4fe3-91e6-a1f60024f7ef</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_bbe0f03c-8ef5-4f8f-b645-9d7c76b30bba</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_bbe30daf-853b-418e-b8c2-3146e4645ad9</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_bde34f16-3fc2-4234-afce-a45390e547b9</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_c2f7eb67-f28a-423c-980b-9cbe0f6d1fa6</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_c49a6aea-4329-496e-ba66-a056c252cccf</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_c69b887d-25c2-4c1b-9a1e-8204ac5184f3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_c87d2ba2-0798-418c-955b-7cefed2019e7</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_c9198fb4-cc40-4782-9f0d-218c8957819d</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>service-instance_ca88288b-b99b-43f8-b88c-885139cd9f52</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_cb537a3f-c564-437c-87f5-6bd4a0596c3f</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_cc14b04f-02b2-49f3-8339-9bd5a089d32d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_ce3b009f-32f5-4119-943c-64ca9e4ad753</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_e702b052-e682-4301-8cbf-813fd5081c89</code></td><td style="text-align:right">3</td><td style="white-space:nowrap">32m – 50m</td></tr>
<tr><td><code>service-instance_e8619775-b050-41c7-9ca6-f5d67d00afc3</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_efd8e21b-7cd3-45d8-9cd4-ba59bc355ce7</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_f1859d44-6e27-45c7-b88f-c41e216afb70</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_f3175ae1-8f78-44ee-be98-45b4b315592d</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_f8fcd35c-a213-4596-b15f-af9ba4aac63a</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">36m – 1h 00m</td></tr>
<tr><td><code>service-instance_fa9c0981-f6b9-42f2-ad54-d31ab7fae81a</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_feb57175-d054-4215-a799-b844cd2b26e0</code></td><td style="text-align:right">1</td><td style="white-space:nowrap">24m – 30m</td></tr>
<tr><td><code>service-instance_ffc946dc-7841-4939-b424-63f06510d47f</code></td><td style="text-align:right">7</td><td style="white-space:nowrap">48m – 1h 30m</td></tr>
<tr><td><code>splunk-nozzle-6ff7292d32faf6ed4b19</code></td><td style="text-align:right">0</td><td style="white-space:nowrap">20m – 20m</td></tr>
</tbody>
</table>


> 15 instance group(s) have `serial:false` — they may update in parallel, so real time can come in under the (conservative serial) estimate.


## Leaf certificates


| Deployment | Leaf certs |
|---|---:|
| `cf-dc3632d155115f0c159e` | 2 |
| `p-healthwatch2-d148bff36cba2d1c7de3` | 1 |


## Operator-supplied certificates — require Digicert


> Not auto-generated. A new certificate must be obtained from Digicert before rotation (out-of-band; not included in the Apply Changes time above).


<table>
<colgroup><col style="width:82%"><col style="width:18%"></colgroup>
<thead><tr><th>Certificate</th><th>Expires</th></tr></thead>
<tbody>
<tr><td><code>.properties.grafana_route.manual.ssl_certificates</code></td><td style="white-space:nowrap">2026-07-08T05:11:33Z</td></tr>
<tr><td><code>.properties.networking_poe_ssl_certs[0].certificate</code></td><td style="white-space:nowrap">2026-07-08T05:11:33Z</td></tr>
<tr><td><code>.uaa.service_provider_key_credentials</code></td><td style="white-space:nowrap">2026-07-08T05:11:33Z</td></tr>
</tbody>
</table>


## Estimate breakdown


| Campaign | Applies | Time (low – high) |
|---|---|---|
| Leaf certs | 1× over 2 deployment(s) | 9h 28m – 23h 10m |
| **Total** | | **9h 28m – 23h 10m** |


## Model & assumptions


- 20m overhead per Apply Changes; 4–10m per VM.
- A FOUNDATION CA = 3 foundation-wide applies; a services TLS CA = 2 foundation + 1 deployment applies; a deployment CA = 3 on its deployment.
- Estimate is **Apply Changes compute time only** — it excludes change-window / approval gaps between phases, which often dominate the wall-clock for CA rotations.
