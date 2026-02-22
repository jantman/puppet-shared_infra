# puppet-shared_infra

Shared Puppet infrastructure classes used by both [privatepuppet](https://github.com/jantman/privatepuppet) and [dm-puppet](https://github.com/DecaturMakers/dm-puppet).

## Classes

- `shared_infra` - Empty anchor class
- `shared_infra::base` - Shared base resources (/root/bin, systemd-reload exec)
- `shared_infra::docker_net` - Docker bridge network named 'custom'
- `shared_infra::promtail` - Promtail log shipping agent (Docker or binary)
- `shared_infra::linux_monitoring` - node-exporter, cAdvisor, systemd-exporter
- `shared_infra::nginx_revproxy` - Nginx reverse proxy in Docker
- `shared_infra::monitoring` - Full monitoring stack (Prometheus, Grafana, Alertmanager, Loki, Ping Exporter)

## Functions

- `shared_infra::goarch()` - Returns Go architecture name for the current system
- `shared_infra::promtail_arch()` - Returns architecture name for promtail downloads (includes ARM support)

## Requirements

- Puppet 8+
- puppetlabs/stdlib >= 9.0.0
- puppetlabs/mysql >= 16.0.0
- puppetlabs/docker
- puppetlabs/firewall (optional, for firewall rule management)
- puppet/archive (for binary installs)

## Usage

Add to your Puppetfile:

```ruby
mod 'shared_infra',
  :git => 'https://github.com/jantman/puppet-shared_infra.git',
  :ref => 'v0.1.0'
```

## Testing

```bash
gem install --user-install rspec-puppet puppetlabs_spec_helper puppet-lint
rake spec
```

## Releasing

1. Update the version in `metadata.json`
2. Commit and push to `main`

The GitHub Actions [release workflow](.github/workflows/release.yml) will automatically tag the commit and create a GitHub Release with a changelog of commits since the previous tag.
