# Shared base resources needed by both privatepuppet and dm-puppet.
class shared_infra::base {

  file {'/root/bin':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  exec {'systemd-reload':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    user        => 'root',
    refreshonly => true,
  }

}
