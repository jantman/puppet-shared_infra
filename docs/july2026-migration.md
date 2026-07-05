# July 2026 Container Upgrade / Migration Guide

This document accompanies the container image bumps made to `shared_infra` in
version `0.10.0`. Several of these cross **major** version boundaries and require
manual steps and/or downstream config changes before or after deploying. Read
this in full before rolling the changes out.

Downstream config (Prometheus scrape config, Loki config, Alertmanager config,
Grafana env, nginx vhosts) lives in the consuming repos
([privatepuppet](https://github.com/jantman/privatepuppet),
[dm-puppet](https://github.com/DecaturMakers/dm-puppet)), **not** in this module,
so most config changes below must be made there.

## Version summary

| Component | Old | New | Severity |
|---|---|---|---|
| Prometheus (`prom/prometheus`) | v2.53.2 | **v3.13.0** | 🔴 major |
| Grafana (`grafana/grafana`) | 11.1.4 | **13.1.0** | 🔴 two majors |
| Grafana image renderer | 3.11.3 | **5.9.1** | 🔴 two majors |
| Loki (`grafana/loki`) | 2.9.10 | **3.7.3** | 🔴 major |
| Alertmanager (`prom/alertmanager`) | v0.27.0 | **v0.33.0** | 🟡 |
| nginx (`nginx`) | 1.27.3-alpine | **1.31.2-alpine** | 🟡 |
| Promtail (`grafana/promtail`) | 3.1.1 | **3.6.11** | 🟡 EOL |
| cAdvisor (`ghcr.io/google/cadvisor`) | 0.56.2 | **0.60.3** | 🟡 |
| ping_exporter (`czerwonk/ping_exporter`) | v1.1.3 | **v1.2.1** | 🟢 |
| apache_exporter (`lusotycoon/apache-exporter`) | v1.0.3 | **v1.1.1** | 🟢 none |
| MongoDB (`mongo`) | 7.0.12-jammy | **7.0.37-jammy** | 🟢 none |
| UniFi (`linuxserver/unifi-network-application`) | 10.4.57-ls134 | **10.4.57-ls135** | 🟢 none |
| unpoller, unifi-logs-loki, zoneminder + sidecars, systemd-exporter, glpi | — | unchanged (already latest) | — |

> **MongoDB stays on the 7.0 line** deliberately — the linuxserver UniFi Network
> Application image only supports MongoDB ≤ 7.0. Do **not** bump `mongo` to 8.x.

## Recommended rollout order

1. **Back up first** (Grafana MySQL DB, Prometheus TSDB, Loki data — see below).
2. **Prometheus**: stage through **v2.55.x** before v3 (rollback path).
3. **Loki** config migration (schema + config keys) — deploy config, then image.
4. **Grafana** (+ image renderer together, they share an auth token).
5. Everything else (Alertmanager, nginx, Promtail, cAdvisor, exporters).

Do one component at a time and confirm health before moving on.

---

## 🔴 Prometheus v2.53.2 → v3.13.0

Migration guide: <https://prometheus.io/docs/prometheus/latest/migration/> ·
Announcement: <https://prometheus.io/blog/2024/11/14/prometheus-3-0/>

### Manual steps
- **Stage through v2.55.x first.** The v3 TSDB format (introduced in 2.55) can only
  be downgraded back to ≥ 2.55, not to 2.53. Run 2.55.x briefly to keep a rollback
  path, then go to v3. (Temporarily set `prometheus_image` to `prom/prometheus:v2.55.1`,
  deploy, verify, then set to v3.13.0.)
- **Back up `/opt/prometheus/data`** before the v3 jump.

### Downstream config changes (in the `prometheus_config_source` files)
- **Stricter scrape `Content-Type`**: scrapes now *fail* on a missing/unknown
  `Content-Type` (v2 silently fell back to text). For any target that doesn't send
  a proper header, add to that scrape job:
  `fallback_scrape_protocol: PrometheusText0.0.4`.
- **Remote-write HTTP/2 now defaults OFF**: if any `remote_write` relied on HTTP/2,
  set `http_config: { enable_http2: true }` in that block.
- **Remove obsolete `--enable-feature` flags** if you add any via
  `prometheus_extra_params`: `promql-at-modifier`, `promql-negative-offset`,
  `remote-write-receiver`, `agent`, `native-histograms`, `no-default-scrape-port`,
  `auto-gomaxprocs`, `auto-gomemlimit`, `expand-external-labels`, etc. are now
  default behavior. Agent mode is `--agent`; the remote-write receiver is
  `--web.enable-remote-write-receiver`.
- **`le` / `quantile` label values are normalized to floats** (`le="1"` → `le="1.0"`).
  Update recording rules, alerts, and Grafana dashboards that match these labels
  by exact string.
- **Auto GOMAXPROCS/GOMEMLIMIT are now on by default** — Prometheus sizes itself to
  the container's CPU/memory limits. Disable with `--no-auto-gomaxprocs` /
  `--no-auto-gomemlimit` (via `prometheus_extra_params`) only if you were tuning
  these manually.
- **PromQL**: regex `.` now matches newlines (use `[^\n]` for old behavior); range
  selectors are now left-open/right-closed (`[5m]` returns exactly 5 samples).
- Requires **Alertmanager ≥ 0.16** with the v2 API (satisfied — see below).

### In this module
No change needed. The hardcoded Prometheus args in `monitoring.pp` (`--config.file`,
`--storage.tsdb.path`, retention, console libs, `--web.enable-admin-api`,
`--web.external-url`, log level) are all still valid in v3.

---

## 🔴 Grafana 11.1.4 → 13.1.0

Upgrade guides: [v12.0](https://grafana.com/docs/grafana/latest/upgrade-guide/upgrade-v12.0/) ·
[v13.0](https://grafana.com/docs/grafana/latest/upgrade-guide/upgrade-v13.0/) ·
[AngularJS removal](https://grafana.com/blog/angularjs-support-will-be-removed-in-grafana-12-what-you-need-to-know/)

### Manual steps
- **Back up the Grafana MySQL database first.** Two irreversible on-startup migrations
  run:
  - **(12.0)** Full rewrite of the `annotation` table (adds `dashboard_uid`). Needs
    ~2–3× the table's size in free disk. Afterward run `OPTIMIZE TABLE annotation;`.
  - **(13.0)** Dashboards/folders migrate to **Unified Storage**
    (`unifiedstorage_migration_log`). Downgrading afterward requires a DB restore.
- We pin **13.1.0** (not 13.0.0). **Do not use 13.0.0** — it had a migration bug that
  could revert/lose dashboards and folders.
- **Audit for AngularJS plugins/panels** before upgrading — Angular support is
  **fully removed in 12.0** with no opt-back-in (`angular_support_enabled` is gone).
  Migrate affected panels/plugins to React equivalents first.

### Downstream config changes (`grafana_env` / nginx)
- **Image rendering now defaults to authenticated (JWT) requests.** You must set a
  shared token on both sides (see the image-renderer section). In `grafana_env`:
  `GF_RENDERING_RENDERER_TOKEN=<token>` (plus your existing
  `GF_RENDERING_SERVER_URL` / `GF_RENDERING_CALLBACK_URL`).
- **`enable_gzip` now defaults ON** (`[server]`). This interacts with the nginx
  reverse proxy in front of Grafana — check for double compression / buffering
  oddities. Set `GF_SERVER_ENABLE_GZIP=false` to restore the old behavior if needed.
- **Data-source UID validation is strict (12.0)**: UIDs must be Latin/numeric/dash and
  ≤ 40 chars, else provisioning/API calls are rejected. Fix invalid UIDs via
  `/api/datasources` and update dashboards/alerts that reference them.
- **Numeric data-source `id` APIs disabled by default (13.0)** — use `uid`-based APIs;
  temporary re-enable via the `datasourceLegacyIdApi` feature flag.
- **RBAC role validation tightened (13.0)** — provisioned/Terraform roles using
  data-source-UID-scoped perms on global roles or legacy annotation scopes are
  rejected; recreate them.
- **`grafana-cli` / `grafana-server` binaries removed (13.0)** — use `grafana cli` /
  `grafana server` in any scripts (not applicable to the stock container entrypoint).
- **React 19 (13.0)** — verify third-party plugins render; **legacy Alertmanager
  endpoints** removed/restricted.

---

## 🔴 Grafana image renderer 3.11.3 → 5.9.1

[CHANGELOG](https://github.com/grafana/grafana-image-renderer/blob/master/CHANGELOG.md) ·
[What's new](https://grafana.com/blog/whats-new-in-the-grafana-image-renderer-higher-quality-results-security-enhancements-and-more/)

> ⚠️ **Tag prefix gotcha:** `grafana/grafana-image-renderer` tags carry a `v`
> prefix — the image is **`grafana/grafana-image-renderer:v5.9.1`**, *not* `:5.9.1`
> (unlike `grafana/grafana:13.1.0`, which has no prefix). The un-prefixed tag 404s
> with `manifest unknown` and the container crash-loops.

### In this module — **change already made (0.10.0)**
`shared_infra::monitoring` now accepts an optional `$grafana_renderer_token`. When
set, it is passed to the renderer container as `AUTH_TOKEN`. Wire it up downstream:

```puppet
class { 'shared_infra::monitoring':
  # ...
  grafana_renderer_token => $my_shared_secret,
  grafana_env            => [
    # ...
    "GF_RENDERING_RENDERER_TOKEN=${my_shared_secret}",
    'GF_RENDERING_SERVER_URL=http://grafanarender:8081/render',
    'GF_RENDERING_CALLBACK_URL=http://grafana:3000/',
  ],
}
```

The two tokens **must match**. Leaving `grafana_renderer_token` unset preserves the
old (no-token) renderer env for backward compatibility.

### Notes / caveats
- **Renderer 5.x requires Grafana ≥ 11.3.8** — satisfied by 13.1.0. ✅
- **(4.0)** Base image switched Alpine → **distroless Debian** (no shell / package
  manager). Any custom image layers, font installs, or `docker exec … sh` on the
  renderer will break.
- **(5.0)** Full Node→Go rewrite; only the remote HTTP service model is supported
  (which is how we run it). Keep the tag pinned.
- Verify the renderer still listens on **8081** after the rewrite; the module maps
  `8081:8081`. If a render returns auth errors, confirm the token env on both sides
  and that `GF_RENDERING_SERVER_URL` points at `…:8081/render`.

---

## 🔴 Loki 2.9.10 → 3.7.3

[Upgrade guide](https://grafana.com/docs/loki/latest/setup/upgrade/) ·
[3.0 release notes](https://grafana.com/docs/loki/latest/release-notes/v3-0/) ·
[Structured metadata](https://grafana.com/docs/loki/latest/get-started/labels/structured-metadata/)

### Manual steps
- **Back up `/opt/loki/data`.**
- Run Loki's **`deprecated-config-checker`** against the current 2.9 config before
  upgrading.
- The Loki 3.x image **dropped BusyBox / `/bin/sh` (3.5.8)** — `docker exec loki sh`
  no longer works. (The config reload in this module uses `docker kill -s SIGHUP`,
  which is unaffected.)

### Downstream config changes (in the `loki_config_source` `loki-config.yaml`)
Loki **will not start** on the new image without these:
- **Add a `v13` / `tsdb` schema period.** In `schema_config.configs`, add a new entry
  with a future `from:` date, `schema: v13`, `store: tsdb`. v13 is compatible with the
  existing 2.9 data, so leave old periods in place and only new data uses v13:
  ```yaml
  schema_config:
    configs:
      - from: 2020-01-01        # existing period(s), unchanged
        store: boltdb-shipper   # (whatever you currently run)
        # ...
      - from: 2026-07-15        # a date >= the deploy date
        store: tsdb
        object_store: filesystem   # was previously shared_store
        schema: v13
        index:
          prefix: index_
          period: 24h
  ```
- **`shared_store` / `shared_store_key_prefix` are removed.** Move the store into each
  `period_config` as `object_store:` (and in `storage_config`/`compactor` as needed).
- **`delete_request_store` is now required** if retention/deletion is enabled
  (compactor won't start without it), e.g. `compactor: { delete_request_store: filesystem }`.
- **Enable structured metadata** (needed by the log shippers, below):
  `limits_config: { allow_structured_metadata: true }`. It defaults on but requires
  the `tsdb` + `v13` schema above. (To defer, set it to `false` instead — but then the
  shippers must run with structured metadata disabled.)
- **Metrics prefix changed `cortex_` → `loki_`.** Update Loki self-monitoring
  dashboards/alerts, or set `metrics_namespace: cortex` to keep the old names.
- **Automatic `service_name` label** is added on ingestion (falls back to
  `unknown_service`). This changes label cardinality and existing queries — disable
  with an empty `discover_service_name` list if undesired.
- **Changed default limits** to review: `max-line-size` unlimited → **256KB** (longer
  lines are now dropped), `max-label-names-per-series` 30 → 15,
  `querier.max-concurrent` 10 → 4, `frontend.max-cache-freshness` 1m → 10m.
- **Removed config** across 3.0/3.1 (must already be off them): legacy stores
  (BoltDB non-shipper, BigTable, Cassandra, DynamoDB), SSD `write`/`read`/`backend`
  and `table-manager` targets, and 14 deprecated keys (e.g.
  `store.max-look-back-period` → `querier.max-query-lookback`).
- **(3.2)** Instant `/api/v1/query` now returns HTTP 400 for log-selector queries — use
  `query_range`.

### Related: the structured-metadata log shippers
`shared_infra::zoneminder` (`zoneminder-loki` v1.0.0) and `shared_infra::unifi`
(`unifi-mongodb-logs-to-loki` v0.1.3) ship logs with **structured metadata**, which
requires **Loki 3.0+ with `allow_structured_metadata: true`**. This Loki bump is what
*enables* that — once Loki 3.x is live with the v13/tsdb schema, those tools work as
intended. No change to the shipper containers is required.

---

## 🟡 Alertmanager v0.27.0 → v0.33.0

[Releases](https://github.com/prometheus/alertmanager/releases)

- **(0.33) `--enable-feature=auto-gomaxprocs` was removed.** If you pass it via
  args, Alertmanager fails to start. (This module does **not** set it — the hardcoded
  args are just `--config.file`, `--storage.path`, `--web.external-url`.)
- **(0.33) Metric `alertmanager_marked_alerts` removed** — update any dashboard/alert
  that references it.
- **(0.28) SNS receiver template errors now hard-fail**; logging switched to `slog`
  (log line format changed — adjust any log parsing).
- UTF-8 matchers remain in fallback mode by default (not forced strict). Validate
  configs with `amtool check-config`.

---

## 🟡 nginx 1.27.3 → 1.31.2 (mainline)

[Changelog](https://nginx.org/en/CHANGES). Config lives in `nginx_revproxy`'s
`dir_source` downstream.

- **(1.27.4) Stricter request parsing** — malformed Host / `:authority`, and bare-LF
  (non-CRLF) chunked bodies are now rejected. Previously-tolerated non-conformant
  clients/upstreams may start getting errors. Main thing to smoke-test on the
  reverse proxy.
- **(1.29.2) `ssl_protocols` in non-default vhosts is now honored** — per-vhost TLS
  settings that were silently ignored now take effect. Verify each `server` block's
  effective TLS protocol set.
- **(1.29.1) TLSv1.3 certificate compression now OFF by default**
  (`ssl_certificate_compression` to re-enable).
- **(1.31.2) `$request_id` now uses SipHash-2-4** — values differ if you log/forward
  it (e.g. as `X-Request-ID`).
- HTTP/2 & HTTP/3 now reject hop-by-hop headers (1.31.0) — only affects h2/h3 clients.

---

## 🟡 Promtail 3.1.1 → 3.6.11

Promtail ships with Loki: [releases](https://github.com/grafana/loki/releases). Config
is generated by `shared_infra::promtail`.

- **⚠️ Promtail is EOL as of 2026-03-02** and was removed from the Loki repo at 3.8.0;
  3.6.x is near the end of the line. **Plan a migration to
  [Grafana Alloy](https://grafana.com/docs/alloy/latest/)** (a config-conversion tool
  exists). This bump buys time, not a long-term home.
- **(3.3.1) `wget` was removed from the Promtail image.** If you add a container
  `HEALTHCHECK` that shells out to `wget`, it will fail. This module defines no such
  healthcheck. ✅
- **(3.3.0) Duplicate `scrape_config` job names are now rejected.** The generated
  config uses distinct job names (`varlog`, `journal`, plus any `additional_scrapes`);
  ensure downstream `additional_scrapes` don't reuse those names.
- Binary-install mode is unaffected — Loki release **v3.6.11** still ships
  `promtail-linux-*.zip` (verified). Loki v3.7.x does **not**, which is why Promtail is
  pinned to 3.6.11 rather than tracking Loki's 3.7.3.

---

## 🟡 cAdvisor 0.56.2 → 0.60.3

[Releases](https://github.com/google/cadvisor/releases). Managed by
`shared_infra::linux_monitoring`.

- **(0.57.0) `container_start_time_seconds` semantics changed** — for Docker/Podman it
  now reports the runtime start time. Uptime/restart graphs and alerts based on it will
  shift. A new **`container_creation_time_seconds`** metric preserves the old
  "creation" meaning — migrate alerts/dashboards to it if you relied on the old value.
- No flags removed/renamed, no metrics removed. (Docker support was *not* dropped.)

---

## 🟢 ping_exporter v1.1.3 → v1.2.1

[Releases](https://github.com/czerwonk/ping_exporter/releases). Config is
`ping_exporter_config_source` downstream.

- **(1.2.0) Labeled-target config format changed.** Targets that carry labels must move
  from the old nested-map form to explicit `host:` + label keys:
  ```yaml
  # OLD:
  targets:
    - google.com: { asn: 15169 }
  # NEW:
  targets:
    - host: google.com
      asn: 15169
  ```
  Plain string targets (`- 127.0.0.1`) are unchanged. Update the config *before*
  deploying the new image.

---

## 🟢 No-action bumps

- **apache_exporter v1.0.3 → v1.1.1** — 1.1.0 only adds optional env-var config;
  1.1.1 is a Go CVE rebuild. No flag/metric/default changes.
- **MongoDB 7.0.12 → 7.0.37-jammy** — patch-level within the 7.0 line (kept ≤ 7.0 for
  UniFi compatibility).
- **UniFi 10.4.57-ls134 → -ls135** — linuxserver base-image rebuild, same UniFi app.

---

## Rollback notes

- **Prometheus**: only down to v2.55.x (TSDB format) — hence staging through it.
- **Grafana**: the 12.0/13.0 DB migrations are one-way; rollback = restore the MySQL
  backup taken beforehand.
- **Loki**: v13 schema data can't be read by 2.9; rollback = restore `/opt/loki/data`
  and revert config (or point back at the pre-v13 period only).
- Everything else can be rolled back by reverting the image tag in Puppet and
  re-running.
