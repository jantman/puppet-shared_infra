# Return the architecture name used for promtail binary downloads.
# Supports arm (armv6l/armv7l) in addition to goarch architectures.
function shared_infra::promtail_arch() >> String {
  $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'aarch64' => 'arm64',
    /^armv/   => 'arm',
    default   => fail("shared_infra::promtail_arch does not support architecture: ${facts['os']['architecture']}"),
  }
}
