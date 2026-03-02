require 'spec_helper'

describe 'shared_infra::glpi' do
  let(:pre_condition) { 'include docker' }
  let(:required_params) do
    { 'mysql_host_in_docker' => 'mariadb' }
  end

  context 'with defaults' do
    let(:params) { required_params }

    it { is_expected.to compile }
    it { is_expected.to contain_mysql_database('glpi').with('charset' => 'utf8mb3', 'collate' => 'utf8mb3_unicode_ci') }
    it { is_expected.to contain_mysql_user('glpi@%') }
    it { is_expected.to contain_mysql_grant('glpi@%/glpi.*').with('privileges' => ['ALL']) }
    it { is_expected.to contain_mysql_grant('glpi@%/mysql.time_zone_name').with('privileges' => ['SELECT']) }
    it { is_expected.to contain_file('/opt/glpi').with('ensure' => 'directory', 'owner' => 33) }
    it { is_expected.to contain_file('/opt/glpi/data').with('ensure' => 'directory') }
    it { is_expected.to contain_file('/opt/glpi/log').with('ensure' => 'directory') }
    it { is_expected.to contain_file('/opt/glpi/config').with('ensure' => 'directory') }
    it {
      is_expected.to contain_docker__run('glpi').with(
        'image' => 'ghcr.io/jantman/docker-glpi:v0.1.0',
        'ports' => ['8088:80'],
      )
    }
    it { is_expected.not_to contain_firewall('441 glpi tcp 8088') }
  end

  context 'with firewall' do
    let(:params) { required_params.merge('manage_firewall' => true) }

    it { is_expected.to compile }
    it { is_expected.to contain_firewall('441 glpi tcp 8088') }
  end

  context 'with custom image, port, and docker_net' do
    let(:params) do
      required_params.merge(
        'glpi_image' => 'ghcr.io/jantman/docker-glpi:v0.2.0',
        'glpi_port'  => '9099',
        'docker_net' => 'custom',
      )
    end

    it { is_expected.to compile }
    it {
      is_expected.to contain_docker__run('glpi').with(
        'image' => 'ghcr.io/jantman/docker-glpi:v0.2.0',
        'ports' => ['9099:80'],
        'net'   => 'custom',
      )
    }
  end

  context 'with custom port and firewall' do
    let(:params) do
      required_params.merge(
        'glpi_port'        => '9099',
        'manage_firewall'  => true,
      )
    end

    it { is_expected.to compile }
    it { is_expected.to contain_firewall('441 glpi tcp 9099') }
  end
end
