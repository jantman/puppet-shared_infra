# Shared monitoring stack: Prometheus, Grafana, Alertmanager, Ping Exporter, Loki
class shared_infra::monitoring (
  String $docker_net,
  # Prometheus
  String $prometheus_image,
  String $prometheus_config_source,
  String $prometheus_external_url,
  Array[String] $prometheus_extra_params = [],
  Optional[String] $prometheus_retention = undef,
  Optional[String] $prometheus_log_level = undef,
  # Grafana
  String $grafana_image,
  String $grafana_renderer_image,
  String $grafana_db_password,
  Array[String] $grafana_env,
  String $grafana_net = $docker_net,
  Hash $grafana_extra_systemd_parameters = {},
  # AlertManager
  String $alertmanager_image,
  String $alertmanager_config_source,
  String $alertmanager_external_url,
  # Ping Exporter
  String $ping_exporter_image,
  String $ping_exporter_config_source,
  # Loki
  String $loki_image,
  String $loki_config_source,
) {

  # Construct prometheus command from base args + optional retention/log_level
  $prom_base_cmd = [
    '--config.file=/etc/prometheus/prometheus.yml',
    '--storage.tsdb.path=/prometheus',
  ]
  $prom_retention_cmd = $prometheus_retention ? {
    undef   => [],
    default => ["--storage.tsdb.retention.time=${prometheus_retention}"],
  }
  $prom_console_cmd = [
    '--web.console.libraries=/usr/share/prometheus/console_libraries',
    '--web.console.templates=/usr/share/prometheus/consoles',
    '--web.enable-admin-api',
    "--web.external-url=${prometheus_external_url}",
  ]
  $prom_loglevel_cmd = $prometheus_log_level ? {
    undef   => [],
    default => ["--log.level=${prometheus_log_level}"],
  }
  $prom_command = join(
    $prom_base_cmd + $prom_retention_cmd + $prom_console_cmd + $prom_loglevel_cmd,
    ' '
  )

  # Config reload execs (standalone, refreshonly — not in chain)
  exec {'prom-config-reload':
    command     => '/usr/bin/docker kill -s SIGHUP prometheus',
    user        => 'root',
    refreshonly => true,
  }
  exec {'alertmanager-config-reload':
    command     => '/usr/bin/docker kill -s SIGHUP alertmanager',
    user        => 'root',
    refreshonly => true,
  }
  exec {'loki-config-reload':
    command     => '/usr/bin/docker kill -s SIGHUP loki',
    user        => 'root',
    refreshonly => true,
  }

  # === Prometheus ===
  file {'/opt/prometheus':
    ensure => directory,
    owner  => 65534,
    group  => 65534,
    mode   => '0755',
  }
  -> file {'/opt/prometheus/data':
    ensure => directory,
    owner  => 65534,
    group  => 65534,
    mode   => '0755',
  }
  -> file {'/opt/prometheus/config':
    ensure  => directory,
    owner   => 65534,
    group   => 65534,
    mode    => '0755',
    purge   => true,
    recurse => true,
    source  => $prometheus_config_source,
    notify  => Exec['prom-config-reload'],
  }
  -> docker::run { 'prometheus':
    image            => $prometheus_image,
    ports            => ['9090:9090'],
    restart_service  => true,
    extra_parameters => ['--restart=always'] + $prometheus_extra_params,
    net              => $docker_net,
    volumes          => [
      '/opt/prometheus/config:/etc/prometheus:ro',
      '/opt/prometheus/data:/prometheus',
    ],
    command          => $prom_command,
  }

  # === Grafana ===
  -> file {'grafana-storage':
    ensure => directory,
    path   => '/opt/grafana',
    owner  => '472',
    group  => '472',
    mode   => '0755',
  }
  -> mysql_database { 'grafana':
    ensure  => 'present',
    charset => 'utf8mb3',
  }
  -> mysql_user { 'grafana@%':
    ensure        => 'present',
    password_hash => mysql::password($grafana_db_password),
  }
  -> mysql_grant { 'grafana@%/grafana.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['ALL'],
    table      => 'grafana.*',
    user       => 'grafana@%',
  }
  -> docker::run { 'grafana':
    image                    => $grafana_image,
    ports                    => ['3000:3000'],
    volumes                  => ['/opt/grafana:/var/lib/grafana'],
    restart_service          => true,
    extra_parameters         => ['--restart=always'],
    env                      => $grafana_env,
    net                      => $grafana_net,
    extra_systemd_parameters => $grafana_extra_systemd_parameters,
  }
  -> docker::run {'grafanarender':
    image            => $grafana_renderer_image,
    ports            => ['8081:8081'],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    env              => ['TZ=America/New_York'],
    net              => $docker_net,
  }

  # === AlertManager ===
  -> file {['/opt/alertmanager', '/opt/alertmanager/data']:
    ensure => directory,
    owner  => 65534,
    group  => 65534,
    mode   => '0755',
  }
  -> file {'/opt/alertmanager/config':
    ensure => directory,
    owner  => 65534,
    group  => 65534,
    mode   => '0755',
  }
  -> file {'/opt/alertmanager/config/alertmanager.yml':
    ensure => present,
    owner  => 65534,
    group  => 65534,
    mode   => '0644',
    source => $alertmanager_config_source,
    notify => Exec['alertmanager-config-reload'],
  }
  -> file {'/opt/alertmanager/config/template':
    ensure  => directory,
    owner   => 65534,
    group   => 65534,
    mode    => '0755',
    purge   => true,
    recurse => true,
    source  => 'puppet:///modules/shared_infra/alertmanager/template',
    notify  => Exec['alertmanager-config-reload'],
  }
  -> docker::run {'alertmanager':
    image            => $alertmanager_image,
    ports            => ['9093:9093'],
    volumes          => [
      '/opt/alertmanager/data:/alertmanager',
      '/opt/alertmanager/config:/etc/alertmanager',
    ],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    net              => $docker_net,
    command          => join([
      '--config.file=/etc/alertmanager/alertmanager.yml',
      '--storage.path=/alertmanager',
      "--web.external-url=${alertmanager_external_url}",
    ], ' '),
  }

  # === Ping Exporter ===
  -> file {'/opt/prometheus/ping-exporter.yml':
    ensure => present,
    owner  => 65534,
    group  => 65534,
    mode   => '0644',
    source => $ping_exporter_config_source,
    notify => Docker::Run['ping-exporter'],
  }
  -> docker::run {'ping-exporter':
    image            => $ping_exporter_image,
    ports            => ['9427:9427'],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    net              => $docker_net,
    env              => ['TZ=America/New_York'],
    volumes          => ['/opt/prometheus/ping-exporter.yml:/config/config.yml:ro'],
  }

  # === Loki ===
  -> file {['/opt/loki', '/opt/loki/data']:
    ensure => directory,
    owner  => 10001,
    group  => 10001,
    mode   => '0755',
  }
  -> file {'/opt/loki/config':
    ensure  => directory,
    owner   => 10001,
    group   => 10001,
    mode    => '0755',
    purge   => true,
    recurse => true,
    source  => $loki_config_source,
    notify  => Exec['loki-config-reload'],
  }
  -> docker::run {'loki':
    image            => $loki_image,
    ports            => ['3100:3100', '9096:9096'],
    volumes          => ['/opt/loki/data:/data', '/opt/loki/config:/mnt/config'],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    net              => $docker_net,
    command          => '-config.file=/mnt/config/loki-config.yaml',
  }
}
