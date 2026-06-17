processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 4000
    spike_limit_mib: 800
  batch:
    send_batch_size: 8192
    timeout: 1s

exporters:
  splunk_hec:
    token: #######
    endpoint: https://10.44.18.25:8088
    source: otel
    sourcetype: otel
    index: pivotal
    timeout: 10s
    tls:
      insecure_skip_verify: true

service:
  pipelines:
    traces:
      processors:
      - memory_limiter
      - batch
      exporters:
      - splunk_hec
    metrics:
      processors:
      - memory_limiter
      - batch
      exporters:
      - splunk_hec
    logs:
      processors:
      - memory_limiter
      - batch
      exporters:
      - splunk_hec
