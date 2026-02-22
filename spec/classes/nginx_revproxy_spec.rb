require 'spec_helper'

describe 'shared_infra::nginx_revproxy' do
  context 'with required params' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      {
        'dir_source'  => 'puppet:///modules/mymod/nginx',
        'docker_host' => '172.19.0.1',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_file('/opt/nginx-revproxy').with_ensure('directory') }
    it { is_expected.to contain_docker__run('nginx-revproxy') }
  end

  context 'with firewall management' do
    let(:pre_condition) { 'include docker' }
    let(:params) do
      {
        'dir_source'      => 'puppet:///modules/mymod/nginx',
        'docker_host'     => '172.19.0.1',
        'manage_firewall' => true,
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_firewall('220 accept nginx_revproxy port 443') }
  end

  context 'with docker_net pre_condition' do
    let(:pre_condition) do
      <<-PUPPET
        include docker
        include shared_infra::docker_net
      PUPPET
    end
    let(:params) do
      {
        'dir_source' => 'puppet:///modules/mymod/nginx',
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_docker__run('nginx-revproxy') }
  end
end
