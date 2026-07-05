# Shared ZoneMinder infrastructure: ZM container + 3 sidecars + DB setup
class shared_infra::zoneminder (
  String $docker_net,
  String $loki_url,
  Array[String] $zm_exporter_env,
  String $shm_size = '8192m',
  String $zm_image = 'ghcr.io/jantman/docker-zoneminder:1.38.1-jantman2',
  String $zm_exporter_image = 'ghcr.io/jantman/zoneminder-prometheus-exporter:v2.1.1',
  String $apache_exporter_image = 'lusotycoon/apache-exporter:v1.1.1',
  String $zoneminder_loki_image = 'ghcr.io/jantman/zoneminder-loki:v1.0.0',
  Array[String] $zm_volumes = [],
  Array[String] $zm_env = [],
  String $zm_base = '/opt/zm',
  Boolean $manage_zm_base = true,
  Boolean $manage_firewall = false,
  Optional[String] $prometheus_host = undef,
  Array[String] $zm_base_dirs = [],
  Array[String] $zm_extra_parameters = [],
) {

  # === Database ===
  mysql_database { 'zm':
    ensure  => 'present',
    charset => 'utf8mb3',
  }
  -> mysql_user { 'zmuser@%':
    ensure        => 'present',
    password_hash => mysql::password('zmpass'),
  }
  -> mysql_grant { 'zmuser@%/zm.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['ALL'],
    table      => 'zm.*',
    user       => 'zmuser@%',
  }

  # === Directories ===
  if $manage_zm_base {
    file { $zm_base:
      ensure  => directory,
      owner   => 33,
      group   => 33,
      mode    => '0755',
      require => Mysql_grant['zmuser@%/zm.*'],
    }
  }
  file {[
    "${zm_base}/config", "${zm_base}/backups",
    "${zm_base}/var-cache", '/var/log/docker-zm',
  ]:
    ensure  => directory,
    owner   => 33,
    group   => 33,
    mode    => '0755',
    require => [Mysql_grant['zmuser@%/zm.*'], File[$zm_base]],
  }

  # Additional directories (e.g. var-cache subdirs)
  if length($zm_base_dirs) > 0 {
    file { $zm_base_dirs:
      ensure  => directory,
      owner   => 33,
      group   => 33,
      mode    => '0755',
      require => File[$zm_base],
    }
  }

  # === Shared ZM API client ===
  file {"${zm_base}/zm_client.py":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/shared_infra/zm_client.py',
    require => File[$zm_base],
  }

  # === ZoneMinder container ===
  $zm_base_volumes = [
    "${zm_base}/backups:/var/backups",
    "${zm_base}/var-cache:/var/cache/zoneminder",
    '/var/log/docker-zm:/var/log/zm',
  ]
  $zm_base_env = [
    'TZ=America/New_York',
    'ZM_DB_HOST=mariadb',
    'ZM_DB_USER=zmuser',
    'ZM_DB_PASS=zmpass',
    'ZM_DB_NAME=zm',
  ]

  File['/var/log/docker-zm']
  -> docker::run { 'zm':
    image            => $zm_image,
    ports            => ['80:80', '9000:9000', '1984:1984', '8555:8555'],
    net              => $docker_net,
    volumes          => $zm_base_volumes + $zm_volumes,
    restart_service  => true,
    extra_parameters => [
      '--restart=always',
      "--shm-size=${shm_size}",
      '--tmpfs /tmp',
      '--tmpfs /run',
      '--ipc="shareable"',
    ] + $zm_extra_parameters,
    env              => $zm_base_env + $zm_env,
    require          => [Docker_network[$docker_net]],
    notify           => [Service['docker-zm-exporter']],
  }

  # === ZM Exporter (Prometheus) ===
  -> docker::run {'zm-exporter':
    image            => $zm_exporter_image,
    ports            => ['8080:8080'],
    net              => $docker_net,
    restart_service  => true,
    extra_parameters => [ '--restart=always', '--ipc="container:zm"'],
    env              => $zm_exporter_env,
  }

  # === Apache Exporter (Prometheus) ===
  -> docker::run {'apache-exporter':
    image            => $apache_exporter_image,
    ports            => ['9117:9117'],
    net              => $docker_net,
    restart_service  => true,
    extra_parameters => [ '--restart=always'],
    command          => '--scrape_uri="http://zm/server-status?auto"',
  }

  # === Zoneminder-Loki pointer file ===
  -> file {"${zm_base}/zoneminder-loki.pointer":
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  # === Zoneminder-Loki container ===
  -> docker::run {'zoneminder-loki':
    image            => $zoneminder_loki_image,
    net              => $docker_net,
    restart_service  => true,
    extra_parameters => [ '--restart=always' ],
    volumes          => [
      "${zm_base}/zoneminder-loki.pointer:/zoneminder-loki.pointer",
    ],
    env              => [
      'TZ=America/New_York',
      "LOKI_URL=${loki_url}",
      "LOG_HOST=${facts['networking']['hostname']}",
      'ZM_DB_HOST=mariadb',
      'ZM_DB_USER=zmuser',
      'ZM_DB_PASS=zmpass',
      'ZM_DB_NAME=zm',
      'POINTER_PATH=/zoneminder-loki.pointer',
    ],
  }

  # === Optional firewall rules ===
  if $manage_firewall {
    Docker::Run['zm-exporter']
    -> firewall {'709 zm-exporter':
      proto  => 'tcp',
      dport  => '8080',
      jump   => 'accept',
      source => $prometheus_host,
    }
    Docker::Run['apache-exporter']
    -> firewall {'708 apache-exporter':
      proto  => 'tcp',
      dport  => '9117',
      jump   => 'accept',
      source => $prometheus_host,
    }
  }
}
