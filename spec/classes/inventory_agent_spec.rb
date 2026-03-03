require 'spec_helper'

describe 'shared_infra::inventory_agent' do
  let(:pre_condition) { 'include shared_infra::base' }
  let(:params) { { 'server' => 'http://glpi.example.com:8088/' } }

  context 'Debian with defaults' do
    it { is_expected.to compile }
    it { is_expected.to contain_package('fusioninventory-agent').with_ensure('present') }
    it { is_expected.to contain_service('fusioninventory-agent.service').with('ensure' => 'stopped', 'enable' => false, 'provider' => 'systemd') }
    it { is_expected.to contain_file('/etc/systemd/system/inventory-agent.service').with('ensure' => 'present', 'mode' => '0644') }
    it { is_expected.to contain_file('/etc/systemd/system/inventory-agent.timer').with('ensure' => 'present', 'mode' => '0644') }
    it { is_expected.to contain_service('inventory-agent.timer').with('ensure' => 'running', 'enable' => true, 'provider' => 'systemd') }
    it { is_expected.to contain_exec('initial-inventory').with_refreshonly(true) }
    it { is_expected.not_to contain_file('/etc/fusioninventory-rpi.xml') }
  end

  context 'Archlinux' do
    let(:facts) do
      {
        'os'             => { 'family' => 'Archlinux', 'name' => 'Archlinux', 'architecture' => 'x86_64',
                              'release' => { 'major' => '2024', 'full' => '2024' } },
        'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
        'facterversion'  => '4.5.0',
        'kernelrelease'  => '6.1.0',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_package('fusioninventory-agent') }
  end

  context 'RPi mode' do
    let(:params) { super().merge('is_rpi' => true) }
    let(:facts) do
      {
        'os'             => { 'family' => 'Debian', 'name' => 'Debian', 'architecture' => 'aarch64',
                              'release' => { 'major' => '12', 'full' => '12.0' },
                              'distro' => { 'codename' => 'bookworm', 'id' => 'Debian' } },
        'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
        'facterversion'  => '4.5.0',
        'kernelrelease'  => '6.1.0',
        'rpi_model'      => 'Raspberry Pi 4 Model B Rev 1.4',
        'rpi_serial'     => '10000000abcdef01',
        'rpi_memory_mb'  => 4096,
        'processors'     => { 'count' => 4, 'models' => ['ARM Cortex-A72'] },
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_file('/etc/fusioninventory-rpi.xml').with('ensure' => 'present', 'mode' => '0644') }
  end

  context 'RPi mode without processors models' do
    let(:params) { super().merge('is_rpi' => true) }
    let(:facts) do
      {
        'os'             => { 'family' => 'Debian', 'name' => 'Debian', 'architecture' => 'armv7l',
                              'release' => { 'major' => '12', 'full' => '12.0' },
                              'distro' => { 'codename' => 'bookworm', 'id' => 'Debian' } },
        'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
        'facterversion'  => '4.5.0',
        'kernelrelease'  => '6.1.0',
        'rpi_model'      => 'Raspberry Pi 3 Model B Rev 1.2',
        'rpi_serial'     => '00000000aabbccdd',
        'rpi_memory_mb'  => 1024,
        'processors'     => { 'count' => 4, 'isa' => 'unknown', 'physicalcount' => 1, 'speed' => '1.20 GHz' },
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_file('/etc/fusioninventory-rpi.xml').with('ensure' => 'present', 'mode' => '0644') }
  end

  context 'custom server' do
    let(:params) { { 'server' => 'http://glpi.example.com:9090/' } }

    it { is_expected.to compile }
    it { is_expected.to contain_exec('initial-inventory').with_command('/usr/bin/fusioninventory-agent -s http://glpi.example.com:9090/') }
  end
end
