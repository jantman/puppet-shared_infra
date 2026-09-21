forge 'forge.puppetlabs.com'

# These pins exist only to supply this module's rspec fixtures; they are not a deployment.
# They are kept aligned with what the consuming repositories actually install, so that
# shared_infra is tested against the module versions it will really run against.
# See jantman/privatepuppet#55.

mod 'puppetlabs-stdlib', '9.7.0'
mod 'puppetlabs-apt', '11.4.0'
mod 'puppet-archive', '8.1.0'
mod 'puppetlabs-mysql', '17.2.0'

# use from git until https://github.com/puppetlabs/puppetlabs-docker/pull/1041 is merged and released
mod 'puppetlabs-docker',
  :git => 'https://github.com/puppetlabs/puppetlabs-docker.git',
  :ref => '6542a45b0e09b7464994343b5fd94eb565265359'

mod 'puppetlabs-firewall', '8.6.0'
