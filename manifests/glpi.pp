# Manage GLPI IT asset management in Docker
class shared_infra::glpi (
  String $mysql_host_in_docker,
  Optional[String] $docker_net = undef,
  String $glpi_image = 'ghcr.io/jantman/docker-glpi:v0.1.0',
  String $glpi_port = '8088',
  Boolean $manage_firewall = false,
) {

  mysql_database { 'glpi':
    ensure  => 'present',
    charset => 'utf8mb3',
    collate => 'utf8mb3_unicode_ci',
  }
  -> mysql_user { 'glpi@%':
    ensure        => 'present',
    password_hash => mysql::password('glpi'),
  }
  -> mysql_grant { 'glpi@%/glpi.*':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['ALL'],
    table      => 'glpi.*',
    user       => 'glpi@%',
  }
  -> mysql_grant { 'glpi@%/mysql.time_zone_name':
    ensure     => 'present',
    options    => ['GRANT'],
    privileges => ['SELECT'],
    table      => 'mysql.time_zone_name',
    user       => 'glpi@%',
  }
  -> file {['/opt/glpi', '/opt/glpi/data', '/opt/glpi/log', '/opt/glpi/config']:
    ensure => directory,
    owner  => 33,
    group  => 33,
    mode   => '0777',
  }
  -> docker::run { 'glpi':
    ensure           => 'present',
    image            => $glpi_image,
    ports            => ["${glpi_port}:80"],
    restart_service  => true,
    extra_parameters => ['--restart=always'],
    volumes          => ['/opt/glpi/data:/app/data', '/opt/glpi/log:/app/log', '/opt/glpi/config:/app/config'],
    net              => $docker_net,
    env              => [
                          'MYSQL_DATABASE=glpi',
                          "MYSQL_HOST=${mysql_host_in_docker}",
                          'MYSQL_USER=glpi',
                          'MYSQL_PASSWORD=glpi',
                          'TZ=America/New_York',
                        ],
  }

  if $manage_firewall {
    Docker::Run['glpi']
    -> firewall {"441 glpi tcp ${glpi_port}":
      proto => 'tcp',
      dport => $glpi_port,
      jump  => 'accept',
    }
  }

}
