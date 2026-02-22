# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `shared_infra`, a Puppet module providing shared infrastructure configuration for both [privatepuppet](https://github.com/jantman/privatepuppet) and [dm-puppet](https://github.com/DecaturMakers/dm-puppet). It targets Puppet 8+ on Debian and Archlinux, managing Docker-based monitoring/logging services (Prometheus, Grafana, Alertmanager, Loki, Promtail) and supporting infrastructure (Nginx reverse proxy, Docker networking).

## Common Commands

```bash
# Install test dependencies (r10k resolves fixtures to spec/fixtures/r10k/)
r10k puppetfile install --moduledir spec/fixtures/r10k

# Run all tests
rake spec

# Run a single spec file
bundle exec rspec spec/classes/promtail_spec.rb

# Lint
puppet-lint --fail-on-warnings manifests/
puppet parser validate manifests/*.pp

# Validate Puppetfile
r10k puppetfile check
```

## Architecture

**Classes** (in `manifests/`):
- `shared_infra` — Empty anchor/namespace class
- `shared_infra::base` — Shared base resources (/root/bin, systemd-reload exec)
- `shared_infra::docker_net` — Docker bridge network (172.19.0.0/24)
- `shared_infra::promtail` — Grafana Promtail with dual-mode deployment (Docker container or binary+systemd)
- `shared_infra::linux_monitoring` — Prometheus exporters (node-exporter, cAdvisor, systemd-exporter), each with Docker or binary mode
- `shared_infra::nginx_revproxy` — Nginx reverse proxy in Docker
- `shared_infra::monitoring` — Full monitoring stack: Prometheus, Grafana (with MySQL), Alertmanager, Ping Exporter, Loki

**Functions** (in `functions/`): `goarch()` and `promtail_arch()` map OS architecture to Go/download architecture names.

**Key patterns**:
- Most services are Docker containers on a shared `custom` bridge network
- Several classes support both Docker and binary (systemd) deployment via parameters
- Config reloads use `docker kill -s HUP` signals rather than container restarts
- Firewall rules are optional — classes check for the firewall module
- Classes are heavily parameterized; resource ordering uses `->` chaining

## Testing

Tests use **rspec-puppet** via `puppetlabs_spec_helper`. Spec files are in `spec/classes/` and `spec/functions/`. Default test facts (in `spec/spec_helper.rb`) simulate Debian 12 (Bookworm) on x86_64.

Dependencies are managed via `.fixtures.yml` which symlinks r10k-installed modules from `spec/fixtures/r10k/`. The `puppetlabs-docker` dependency uses a git reference to a specific commit (pending PR #1041).

Ruby 3.4 requires explicit `require` for syslog, ostruct, and benchmark gems (handled in spec_helper.rb).

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs two jobs on Ruby 3.4: **lint** (puppet-lint + parser validate + puppetfile check) and **test** (r10k puppetfile install + rake spec).

## Releasing

Tags follow `vX.Y.Z` format. Pushing a tag triggers `.github/workflows/release.yml`, which generates a changelog and creates a GitHub Release.

```bash
# Update version in metadata.json, then:
git commit -am "Release vX.Y.Z"
git tag vX.Y.Z
git push origin main --tags
```

## Linting

`.puppet-lint.rc` enables `--fail-on-warnings` and disables `autoloader_layout` and `parameter_order` checks.
