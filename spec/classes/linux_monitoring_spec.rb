require 'spec_helper'

describe 'shared_infra::linux_monitoring' do
  let(:non_docker_facts) do
    {
      'os'             => { 'architecture' => 'x86_64', 'family' => 'Debian', 'name' => 'Debian',
                            'release' => { 'major' => '12', 'full' => '12.0' },
                            'distro' => { 'codename' => 'bookworm', 'id' => 'Debian' } },
      'networking'     => { 'hostname' => 'testhost', 'ip' => '10.0.0.1' },
      'facterversion'  => '4.5.0',
      'kernelrelease'  => '6.1.0',
    }
  end

  context 'Docker mode (default)' do
    let(:pre_condition) { 'include docker' }

    it { is_expected.to compile }
    it { is_expected.to contain_package('prometheus-node-exporter') }
    it { is_expected.to contain_service('prometheus-node-exporter.service').with_ensure('running') }
    it { is_expected.to contain_docker__run('cadvisor') }
    it { is_expected.to contain_docker__run('systemd-exporter') }
  end

  context 'Docker mode with firewall' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      {
        'manage_firewall' => true,
        'firewall_source' => '10.0.0.0/8',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_firewall('443 prometheus-node-exporter tcp 9100') }
    it { is_expected.to contain_firewall('444 prometheus-systemd-exporter tcp 9558') }
    it { is_expected.to contain_firewall('445 cadvisor tcp 8099') }
  end

  context 'Docker mode with node-exporter-args' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      {
        'manage_node_exporter_args' => true,
        'node_exporter_args'        => '--collector.textfile',
        'node_args_path'            => '/etc/default/prometheus-node-exporter',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_file('prometheus-node-exporter-args').with_path('/etc/default/prometheus-node-exporter') }
  end

  context 'non-Docker x86_64' do
    let(:params) { { 'have_docker' => false } }
    let(:pre_condition) { 'include shared_infra::base' }
    let(:facts) { non_docker_facts }

    it { is_expected.to compile }
    it { is_expected.to contain_archive('/tmp/systemd_exporter.tgz') }
    it { is_expected.to contain_file('/etc/systemd/system/systemd_exporter.service') }
    it { is_expected.to contain_service('systemd_exporter.service').with_ensure('running') }
    it { is_expected.not_to contain_docker__run('cadvisor') }
    it { is_expected.not_to contain_docker__run('systemd-exporter') }
  end

  context 'non-Docker aarch64' do
    let(:params) { { 'have_docker' => false } }
    let(:pre_condition) { 'include shared_infra::base' }
    let(:facts) do
      non_docker_facts.merge('os' => non_docker_facts['os'].merge('architecture' => 'aarch64'))
    end

    it { is_expected.to compile }
    it { is_expected.to contain_archive('/tmp/systemd_exporter.tgz') }
  end

  context 'non-Docker with custom service name' do
    let(:params) do
      {
        'have_docker'         => false,
        'sysexp_service_name' => 'my-systemd-exporter',
      }
    end
    let(:pre_condition) { 'include shared_infra::base' }
    let(:facts) { non_docker_facts }

    it { is_expected.to compile }
    it { is_expected.to contain_file('/etc/systemd/system/my-systemd-exporter.service') }
    it { is_expected.to contain_service('my-systemd-exporter.service').with_ensure('running') }
  end
end
