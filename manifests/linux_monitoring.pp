# Linux monitoring agents: node-exporter, cAdvisor, systemd-exporter.
# Merged from privatepuppet::prometheus_target and dmpuppet::internals::linux_monitoring.
class shared_infra::linux_monitoring (
  Boolean $have_docker = true,
  String $docker_net = 'custom',
  String $cadvisor_image = 'gcr.io/cadvisor/cadvisor:v0.47.2',
  String $systemd_exporter_version = '0.6.0',
  Boolean $manage_firewall = false,
  Optional[String] $firewall_source = undef,
  Boolean $manage_node_exporter_args = false,
  Optional[String] $node_exporter_args = undef,
  Optional[String] $node_args_path = undef,
  String $node_args_comment = '# managed by shared_infra::linux_monitoring',
  String $systemd_exporter_service_source = 'puppet:///modules/shared_infra/linux_monitoring/systemd_exporter.service',
  String $sysexp_service_name = 'systemd_exporter',
) {

  $systemd_command = [
    '--systemd.collector.enable-restart-count', # systemd >= 235
    '--systemd.collector.enable-ip-accounting', # systemd >= 235
    '--log.level=error',
  ]

  package {['prometheus-node-exporter']:
    ensure => present,
  }

  if ($manage_node_exporter_args) {
    Package['prometheus-node-exporter']
    -> file {'prometheus-node-exporter-args':
      ensure  => present,
      path    => $node_args_path,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => @("EOT"),
        ${node_args_comment}
        ARGS="${node_exporter_args}"
        NODE_EXPORTER_ARGS="${node_exporter_args}"
        | EOT
      notify  => Service['prometheus-node-exporter.service'],
    }
    -> Service['prometheus-node-exporter.service']
  } else {
    Package['prometheus-node-exporter']
    -> Service['prometheus-node-exporter.service']
  }

  service {'prometheus-node-exporter.service':
    ensure => running,
    enable => true,
  }

  if ($manage_firewall) {
    Service['prometheus-node-exporter.service']
    -> firewall {'443 prometheus-node-exporter tcp 9100':
      proto  => 'tcp',
      dport  => '9100',
      jump   => 'accept',
      source => $firewall_source,
    }

    firewall {'444 prometheus-systemd-exporter tcp 9558':
      proto  => 'tcp',
      dport  => '9558',
      jump   => 'accept',
      source => $firewall_source,
    }
  }

  if $have_docker == true {
    docker::run {'cadvisor':
      image            => $cadvisor_image,
      ports            => ['8099:8080'],
      restart_service  => true,
      extra_parameters => [ '--restart=always' ],
      net              => $docker_net,
      volumes          => [
                            '/:/rootfs:ro',
                            '/var/run:/var/run:rw',
                            '/sys:/sys:ro',
                            '/var/lib/docker/:/var/lib/docker:ro',
                          ],
    }

    if ($manage_firewall) {
      Docker::Run['cadvisor']
      -> firewall {'445 cadvisor tcp 8099':
        proto  => 'tcp',
        dport  => '8099',
        jump   => 'accept',
        source => $firewall_source,
      }
      -> Docker::Run['systemd-exporter']
    }

    docker::run {'systemd-exporter':
      image            => "prometheuscommunity/systemd-exporter:v${systemd_exporter_version}",
      ports            => ['9558:9558'],
      restart_service  => true,
      extra_parameters => [ '--restart=always', '--pid=host' ],
      privileged       => true,
      net              => $docker_net,
      command          => join($systemd_command, ' '),
      volumes          => [
        '/proc:/host/proc:ro',
        '/run/systemd:/run/systemd:ro',
        '/sys:/sys:ro',
        '/var/run:/var/run:ro',
      ],
    }
  } else {
    $sysexp_arch = shared_infra::promtail_arch()
    archive {'/tmp/systemd_exporter.tgz':
      ensure          => present,
      extract         => true,
      extract_path    => '/usr/local/bin',
      # lint:ignore:140chars
      source          => "https://github.com/prometheus-community/systemd_exporter/releases/download/v${systemd_exporter_version}/systemd_exporter-${systemd_exporter_version}.linux-${sysexp_arch}.tar.gz",
      extract_command => "tar xfz %s --strip-components=1 systemd_exporter-${systemd_exporter_version}.linux-${sysexp_arch}/systemd_exporter",
      # lint:endignore
      creates         => '/usr/local/bin/systemd_exporter',
    }
    -> file {"/etc/systemd/system/${sysexp_service_name}.service":
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => $systemd_exporter_service_source,
      notify => [Exec['systemd-reload'], Service["${sysexp_service_name}.service"]],
    }
    -> service {"${sysexp_service_name}.service":
      ensure => running,
      enable => true,
    }
    exec {'systemd-exporter-chmod':
      command   => '/usr/bin/chmod 0755 /usr/local/bin/systemd_exporter',
      subscribe => Archive['/tmp/systemd_exporter.tgz'],
    }
  }

}
