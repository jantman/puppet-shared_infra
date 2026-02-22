require 'spec_helper'

describe 'shared_infra::promtail' do
  let(:params) do
    { 'loki_host' => 'loki.example.com' }
  end

  context 'Docker mode (default)' do
    let(:pre_condition) { 'include docker' }

    it { is_expected.to compile }
    it { is_expected.to contain_file('/opt/promtail').with_ensure('directory') }
    it { is_expected.to contain_file('/opt/promtail/promtail.yaml') }
    it { is_expected.to contain_docker__run('promtail') }
    it { is_expected.to contain_exec('promtail-reload').with_refreshonly(true) }
    it { is_expected.not_to contain_service('promtail') }
  end

  context 'Docker mode with firewall' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      super().merge(
        'manage_firewall' => true,
        'firewall_source' => '10.0.0.0/8',
      )
    end

    it { is_expected.to compile }
    it { is_expected.to contain_firewall('800 promtail http metrics tcp 9080') }
  end

  context 'non-Docker x86_64' do
    let(:params) do
      super().merge('use_docker' => false)
    end
    let(:pre_condition) { 'include shared_infra::base' }
    let(:facts) do
      {
        'os'             => { 'architecture' => 'x86_64', 'family' => 'Debian', 'name' => 'Debian',
                              'release' => { 'major' => '12', 'full' => '12.0' },
                              'distro' => { 'codename' => 'bookworm', 'id' => 'Debian' } },
        'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
        'facterversion'  => '4.5.0',
        'kernelrelease'  => '6.1.0',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_archive('promtail') }
    it { is_expected.to contain_file('/usr/local/bin/promtail').with_ensure('symlink') }
    it { is_expected.to contain_file('/etc/systemd/system/promtail.service') }
    it { is_expected.to contain_service('promtail').with_ensure('running') }
    it { is_expected.not_to contain_docker__run('promtail') }
  end

  context 'non-Docker aarch64' do
    let(:params) do
      super().merge('use_docker' => false)
    end
    let(:pre_condition) { 'include shared_infra::base' }
    let(:facts) do
      {
        'os'             => { 'architecture' => 'aarch64', 'family' => 'Debian', 'name' => 'Debian',
                              'release' => { 'major' => '12', 'full' => '12.0' },
                              'distro' => { 'codename' => 'bookworm', 'id' => 'Debian' } },
        'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
        'facterversion'  => '4.5.0',
        'kernelrelease'  => '6.1.0',
      }
    end

    it { is_expected.to compile }
    it {
      is_expected.to contain_file('/usr/local/bin/promtail').with(
        'ensure' => 'symlink',
        'target' => '/usr/local/bin/promtail-linux-arm64',
      )
    }
  end

  context 'no journald or varlog scraping' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      super().merge(
        'scrape_journald' => false,
        'scrape_varlog'   => false,
      )
    end

    it { is_expected.to compile }
  end
end
