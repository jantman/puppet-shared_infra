# Nginx reverse proxy running in Docker.
# Merged from privatepuppet::nginx_revproxy and dmpuppet::internals::nginx_revproxy.
class shared_infra::nginx_revproxy(
  $dir_source,
  $ports         = [443],
  $docker_host   = undef,
  $net           = 'custom',
  $nginx_image   = 'nginx:1.27.3-alpine',
  Boolean $manage_firewall = false,
) {

  if $docker_host == undef {
    $real_docker_host = $shared_infra::docker_net::custom_gateway
  } else {
    $real_docker_host = $docker_host
  }

  if ($manage_firewall) {
    $ports.each |Integer $port| {
      firewall {"220 accept nginx_revproxy port ${port}":
        proto => 'tcp',
        dport => $port,
        jump  => 'accept',
      }
    }
  }

  $container_ports = map($ports) |$portnum| { "${portnum}:${portnum}" }

  file { '/opt/nginx-revproxy':
    ensure  => directory,
    owner   => 'root',
    mode    => '0755',
    purge   => true,
    recurse => true,
    source  => $dir_source,
    notify  => Service['docker-nginx-revproxy'],
  }
  -> docker::run { 'nginx-revproxy':
    image            => $nginx_image,
    ports            => $container_ports,
    net              => $net,
    volumes          => [
      '/opt/nginx-revproxy/nginx.conf:/etc/nginx/nginx.conf:ro',
      '/opt/nginx-revproxy/certs:/etc/nginx/certs:ro',
      '/opt/nginx-revproxy/conf.d:/etc/nginx/conf.d:ro',
      '/opt/nginx-revproxy/html:/etc/nginx/html:ro',
    ],
    restart_service  => true,
    extra_parameters => ['--restart=always', "--add-host='dockerhost:${real_docker_host}'"],
  }

}
