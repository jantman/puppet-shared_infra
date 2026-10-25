# Return the architecture name used for promtail binary downloads.
# Supports arm (armv6l/armv7l, and Debian's armhf as reported by 32-bit userland on an
# aarch64 kernel, e.g. OSMC on the Vero) in addition to goarch architectures.
function shared_infra::promtail_arch() >> String {
  $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'aarch64' => 'arm64',
    /^armv/   => 'arm',
    'armhf'   => 'arm',
    default   => fail("shared_infra::promtail_arch does not support architecture: ${facts['os']['architecture']}"),
  }
}
