# Class: shared_infra::docker_net
#
# Creates a Docker bridge network named 'custom'.
#
class shared_infra::docker_net (
  $custom_subnet   = '172.19.0.0/24',
  $custom_gateway  = '172.19.0.1',
){
  docker_network { 'custom':
    ensure  => present,
    driver  => 'bridge',
    subnet  => $custom_subnet,
    gateway => $custom_gateway,
  }
}
