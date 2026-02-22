# Given the architecture of the current machine, return the
# architecture name used for Go builds.
function shared_infra::goarch() >> String {
  $result = $facts['os']['architecture'] ? {
    'x86_64'  => 'amd64',
    'aarch64' => 'arm64',
    default   => undef,
  }
  if ($result == undef) {
    fail("shared_infra::goarch does not support architecture: ${facts['os']['architecture']}")
  }
  $result
}
