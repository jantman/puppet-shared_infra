# Manage Promtail log shipping agent
#
# Supports both Docker-based and binary (systemd service) deployment.
# Merged from privatepuppet::promtail and dmpuppet::internals::promtail.
#
class shared_infra::promtail(
  String $loki_host,
  Boolean $use_docker = true,
  String $docker_net = 'custom',
  Boolean $scrape_journald = true,
  Boolean $scrape_varlog = true,
  String $promtail_version = '3.1.1',
  Optional[Array[Hash]] $additional_scrapes = undef,
  Optional[Array[String]] $additional_mounts = undef,
  Boolean $manage_firewall = false,
  Optional[String] $firewall_source = undef,
  String $config_comment = '# managed by shared_infra::promtail',
) {

  $base_volumes = [
    '/opt/promtail:/opt/promtail',
    '/var/log:/var/log:ro',
    '/run/log:/run/log:ro',
    '/etc/machine-id:/etc/machine-id:ro'
  ]

  if ($additional_mounts != undef) {
    $volumes = $base_volumes + $additional_mounts
  } else {
    $volumes = $base_volumes
  }

  if($scrape_varlog == true) {
    $varlog_scrape = {
      'job_name' => 'varlog',
      'pipeline_stages' => [],
      'static_configs' => [
        {
          'labels'  => {
            'job' => 'varlog',
            'host' => $facts['networking']['hostname'],
            '__path__' => '/var/log/**/*.log'
          }
        }
      ]
    }
  } else {
    $varlog_scrape = undef
  }

  if($scrape_journald == true) {
    $journald_scrape = {
      'job_name' => 'journal',
      'journal'  => {
        'json' => false,
        'max_age' => '12h',
        'labels' => {
          'job'  => 'systemd-journal',
          'host' => $facts['networking']['hostname'],
        }
      },
      'relabel_configs' => [
        {
          'source_labels' => ['__journal__systemd_unit'],
          'target_label' => 'unit'
        },
        {
          'source_labels' => ['__journal__hostname'],
          'target_label' => 'nodename'
        },
        {
          'source_labels' => ['__journal_syslog_identifier'],
          'target_label' => 'syslog_identifier'
        },
      ]
    }
  } else {
    $journald_scrape = undef
  }

  $tmp_scrapes = [$varlog_scrape, $journald_scrape]

  if($additional_scrapes != undef) {
    $scrapes = $tmp_scrapes + $additional_scrapes
  } else {
    $scrapes = $tmp_scrapes
  }

  $config = {
    'server' => {
      'http_listen_port' => 9080,
      'grpc_listen_port' => 0,
    },
    'positions' => {
      'filename' => '/opt/promtail/positions.yaml',
    },
    'clients' => [
      {'url' => "http://${loki_host}:3100/loki/api/v1/push"}
    ],
    'scrape_configs' => delete_undef_values($scrapes),  # stdlib function
  }
  $config_str = to_yaml($config)  # to_yaml() is a stdlib function

  file {'/opt/promtail':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  if ($use_docker == true) {
    exec {'promtail-reload':
      command     => '/usr/bin/docker kill -s SIGHUP promtail',
      user        => 'root',
      refreshonly => true,
    }

    if ($manage_firewall) {
      firewall {'800 promtail http metrics tcp 9080':
        proto  => 'tcp',
        dport  => '9080',
        jump   => 'accept',
        source => $firewall_source,
      }
      -> File['/opt/promtail']
    }

    File['/opt/promtail']
    -> file {'/opt/promtail/promtail.yaml':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "${config_comment}\n${config_str}",
      notify  => Exec['promtail-reload'],
    }
    -> docker::run {'promtail':
      image            => "grafana/promtail:${promtail_version}",
      ports            => ['9080:9080'],
      volumes          => $volumes,
      restart_service  => true,
      extra_parameters => [ '--restart=always' ],
      net              => $docker_net,
      command          => '-config.file=/opt/promtail/promtail.yaml'
    }
  } else {
    # Non-Docker binary install path
    file {'/opt/promtail/promtail.yaml':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "${config_comment}\n${config_str}",
      require => File['/opt/promtail'],
      notify  => Service['promtail'],
    }

    $promtail_arch = shared_infra::promtail_arch()

    archive{'promtail':
      path         => '/tmp/promtail.zip',
      source       => "https://github.com/grafana/loki/releases/download/v${promtail_version}/promtail-linux-${promtail_arch}.zip",
      extract      => true,
      extract_path => '/usr/local/bin',
      creates      => "/usr/local/bin/promtail-linux-${promtail_arch}",
      cleanup      => true,
    }
    -> file {"/usr/local/bin/promtail-linux-${promtail_arch}":
      owner => 'root',
      group => 'root',
      mode  => '0755',
    }
    -> file {'/usr/local/bin/promtail':
      ensure => symlink,
      target => "/usr/local/bin/promtail-linux-${promtail_arch}",
    }
    -> file {'/etc/systemd/system/promtail.service':
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/shared_infra/promtail/promtail.service',
      notify => [Exec['systemd-reload'], Service['promtail']],
    }
    -> service {'promtail':
      ensure => running,
      enable => true,
    }
  }

}
