# Return the architecture name used for systemd_exporter binary downloads.
# Unlike promtail which uses generic 'arm', systemd_exporter releases
# use specific ARM versions (armv5, armv6, armv7).
function shared_infra::sysexp_arch() >> String {
  $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'aarch64' => 'arm64',
    'armv5l'  => 'armv5',
    'armv6l'  => 'armv6',
    'armv7l'  => 'armv7',
    default   => fail("shared_infra::sysexp_arch does not support architecture: ${facts['os']['architecture']}"),
  }
}
