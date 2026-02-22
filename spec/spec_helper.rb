# Pre-require gems removed from Ruby 3.4+ defaults before puppet loads them
require 'syslog'
require 'ostruct'
require 'benchmark'

require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.default_facts = {
    'os' => {
      'name'         => 'Debian',
      'family'       => 'Debian',
      'architecture' => 'x86_64',
      'release'      => { 'major' => '12', 'full' => '12.0' },
      'distro'       => {
        'codename' => 'bookworm',
        'id'       => 'Debian',
      },
    },
    'networking' => {
      'hostname' => 'testhost',
      'ip'       => '10.0.0.1',
    },
    'operatingsystem'        => 'Debian',
    'osfamily'               => 'Debian',
    'operatingsystemrelease' => '12.0',
    'lsbdistcodename'        => 'bookworm',
    'kernelrelease'          => '6.1.0',
    'facterversion'          => '4.5.0',
  }
end
