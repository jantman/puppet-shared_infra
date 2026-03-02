# Manage computer inventory agent (currently FusionInventory)
# @param server GLPI server URL, e.g. 'http://glpi.example.com:8088/'
class shared_infra::inventory_agent (
  String $server,
  Boolean $is_rpi = false,
  String $config_comment = '# managed by shared_infra::inventory_agent',
) {

  case $facts['os']['family'] {
    /Archlinux/: {
      $package  = 'fusioninventory-agent'
      $bin_path = '/usr/bin/fusioninventory-agent'
    }
    /Debian/: {
      $package  = 'fusioninventory-agent'
      $bin_path = '/usr/bin/fusioninventory-agent'
    }
    default: {
      fail("shared_infra::inventory_agent ERROR: osfamily ${facts['os']['family']} is not supported")
    }
  }

  package { $package:
    ensure => present,
  }
  -> service { 'fusioninventory-agent.service':
    ensure   => stopped,
    enable   => false,
    provider => systemd,
  }

  if $is_rpi {
    file { '/etc/fusioninventory-rpi.xml':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => template('shared_infra/inventory_agent/fusioninventory-rpi.xml.erb'),
      require => Service['fusioninventory-agent.service'],
    }
  }

  file { '/etc/systemd/system/inventory-agent.service':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('shared_infra/inventory_agent/inventory-agent.service.erb'),
    notify  => Exec['systemd-reload'],
    require => Service['fusioninventory-agent.service'],
  }
  -> file { '/etc/systemd/system/inventory-agent.timer':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/shared_infra/inventory_agent/inventory-agent.timer',
    notify => Exec['systemd-reload'],
  }
  -> service { 'inventory-agent.timer':
    ensure   => running,
    enable   => true,
    provider => systemd,
  }
  -> exec { 'initial-inventory':
    command     => "${bin_path} -s ${server}",
    user        => 'root',
    refreshonly => true,
  }

}
