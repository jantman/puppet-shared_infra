# Shared UniFi Network Application infrastructure:
# MongoDB, UniFi controller, unPoller, and unifi-logs-loki containers
class shared_infra::unifi (
  String $unpoller_unifi_url,
  String $unpoller_loki_url,
  String $logs_loki_url,
  String $logs_loki_log_host,
  String $docker_net = 'custom',
  String $unifi_image_tag = '10.1.89-ls121',
  String $mongo_image = 'mongo:7.0.12-jammy',
  Optional[String] $mongo_command = undef,
  Optional[String] $mongo_hostname = undef,
  String $config_dir = '/opt/unifi8',
  String $init_mongo_source = 'puppet:///modules/shared_infra/unifi/init-mongo.js',
  Boolean $manage_firewall = false,
  Hash $extra_systemd_parameters = {},
  String $unpoller_image = 'ghcr.io/unpoller/unpoller:v2.34.0',
  String $unpoller_user = 'monitoring',
  String $unpoller_pass = 'm0n1t0r1ng',
  Boolean $unpoller_save_dpi = false,
  String $unpoller_net = 'custom',
  String $logs_loki_image = 'ghcr.io/jantman/unifi-mongodb-logs-to-loki:v0.1.3',
) {

  # User and group
  group {'unifi':
    ensure => present,
    system => true,
    gid    => 120,
  }
  -> user {'unifi':
    ensure     => present,
    gid        => 'unifi',
    home       => $config_dir,
    managehome => false,
    shell      => '/usr/sbin/nologin',
    system     => true,
    uid        => 120,
  }

  # MongoDB directories
  -> file {'/opt/unifi-mongodb':
    ensure => directory,
    owner  => 999,
    group  => 999,
    mode   => '0750',
  }
  -> file {['/opt/unifi-mongodb/docker-entrypoint-initdb.d', '/opt/unifi-mongodb/data-db', '/opt/unifi-mongodb/backup']:
    ensure => directory,
    owner  => 999,
    group  => 999,
    mode   => '0750',
  }
  -> file {'/opt/unifi-mongodb/docker-entrypoint-initdb.d/init-mongo.js':
    ensure => present,
    owner  => 999,
    group  => 999,
    mode   => '0655',
    source => $init_mongo_source,
  }

  # MongoDB container
  -> docker::run {'unifi-mongodb':
    hostname         => $mongo_hostname,
    image            => $mongo_image,
    ports            => [
      '27017:27017',
    ],
    volumes          => [
      '/opt/unifi-mongodb/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d:ro',
      '/opt/unifi-mongodb/data-db:/data/db',
      '/opt/unifi-mongodb/backup:/backup',
      '/etc/localtime:/etc/localtime:ro',
    ],
    env              => [
      'TZ=America/New_York',
    ],
    command          => $mongo_command,
    restart_service  => true,
    extra_parameters => ['--restart=always',],
    net              => $docker_net,
  }

  # UniFi config directory
  -> file {$config_dir:
    ensure => directory,
    owner  => 'unifi',
    group  => 'unifi',
    mode   => '0750',
  }
  -> file {"${config_dir}/resume_token.pkl":
    ensure => file,
    owner  => 'unifi',
    group  => 'unifi',
    mode   => '0644',
  }

  # UniFi Network Application container
  -> docker::run {'unifi':
    image                    => "lscr.io/linuxserver/unifi-network-application:${unifi_image_tag}",
    ports                    => [
      '1900:1900/udp',
      '3478:3478/udp',
      '8080:8080',
      '8443:8443',
      '8843:8843',
      '8880:8880',
      '6789:6789',
      '10001:10001/udp',
      '5514:5514/udp',
    ],
    volumes                  => [
      "${config_dir}:/config",
      '/etc/localtime:/etc/localtime:ro',
    ],
    env                      => [
      'TZ=America/New_York',
      'PUID=120',
      'PGID=120',
      'MONGO_USER=unifi',
      'MONGO_PASS=unifi',
      'MONGO_HOST=unifi-mongodb',
      'MONGO_PORT=27017',
      'MONGO_DBNAME=unifi',
    ],
    restart_service          => true,
    extra_parameters         => ['--restart=always',],
    net                      => $docker_net,
    extra_systemd_parameters => $extra_systemd_parameters,
  }

  # Optional firewall rules
  if $manage_firewall {
    Firewall {
      jump => 'accept',
    }
    firewall {'600 accept UDP 3478 for unifi STUN':
      proto => 'udp',
      dport => '3478',
    }
    -> firewall {'601 accept TCP 8080 for unifi devices':
      proto => 'tcp',
      dport => '8080',
    }
    -> firewall {'602 accept TCP 8443 for unifi UI':
      proto => 'tcp',
      dport => '8443',
    }
    -> firewall {'603 accept TCP 6789 for unifi mobile speedtest':
      proto => 'tcp',
      dport => '6789',
    }
    -> firewall {'605 accept UDP 10001 for unifi discovery':
      proto => 'udp',
      dport => '10001',
    }
    -> firewall {'606 accept UDP 5514 for unifi syslog':
      proto => 'udp',
      dport => '5514',
    }
  }

  # unPoller container
  docker::run {'unpoller':
    image            => $unpoller_image,
    ports            => ['9130:9130'],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    net              => $unpoller_net,
    env              => [
      "UP_UNIFI_DEFAULT_URL=${unpoller_unifi_url}",
      "UP_UNIFI_DEFAULT_USER=${unpoller_user}",
      "UP_UNIFI_DEFAULT_PASS=${unpoller_pass}",
      "UP_UNIFI_DEFAULT_SAVE_DPI=${unpoller_save_dpi}",
      'UP_UNIFI_DEFAULT_SAVE_IDS=true',
      'UP_UNIFI_DEFAULT_SAVE_ALARMS=true',
      'UP_UNIFI_DEFAULT_SAVE_EVENTS=true',
      'UP_UNIFI_DEFAULT_SAVE_ANOMALIES=true',
      'UP_LOKI_DISABLE=false',
      "UP_LOKI_URL=${unpoller_loki_url}",
    ],
  }

  # unifi-logs-loki container
  docker::run {'unifi-logs-loki':
    image            => $logs_loki_image,
    volumes          => [
      '/etc/localtime:/etc/localtime:ro',
      "${config_dir}/resume_token.pkl:/resume_token.pkl",
    ],
    env              => [
      'TZ=America/New_York',
      "LOG_HOST=${logs_loki_log_host}",
      "LOKI_URL=${logs_loki_url}",
      'MONGODB_CONN_STR=mongodb://unifi-mongodb:27017/',
    ],
    restart_service  => true,
    extra_parameters => ['--restart=always',],
    net              => $docker_net,
  }

}
