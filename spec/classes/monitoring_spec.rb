require 'spec_helper'

describe 'shared_infra::monitoring' do
  let(:pre_condition) { 'include docker' }
  let(:params) do
    {
      'docker_net'                  => 'custom',
      'prometheus_image'            => 'prom/prometheus:v2.50.0',
      'prometheus_config_source'    => 'puppet:///modules/mymod/prometheus',
      'prometheus_external_url'     => 'http://prometheus.example.com',
      'grafana_image'               => 'grafana/grafana:10.3.1',
      'grafana_renderer_image'      => 'grafana/grafana-image-renderer:3.9.0',
      'grafana_db_password'         => 'testpassword',
      'grafana_env'                 => ['GF_SERVER_ROOT_URL=http://grafana.example.com'],
      'alertmanager_image'          => 'prom/alertmanager:v0.27.0',
      'alertmanager_config_source'  => 'puppet:///modules/mymod/alertmanager.yml',
      'alertmanager_external_url'   => 'http://alertmanager.example.com',
      'ping_exporter_image'         => 'czerwonk/ping_exporter:v1.1.0',
      'ping_exporter_config_source' => 'puppet:///modules/mymod/ping-exporter.yml',
      'loki_image'                  => 'grafana/loki:2.9.4',
      'loki_config_source'          => 'puppet:///modules/mymod/loki',
    }
  end

  context 'with required params' do
    it { is_expected.to compile }

    # Prometheus
    it { is_expected.to contain_docker__run('prometheus') }
    it { is_expected.to contain_file('/opt/prometheus/config') }
    it { is_expected.to contain_exec('prom-config-reload').with_refreshonly(true) }

    # Grafana
    it { is_expected.to contain_docker__run('grafana') }
    it { is_expected.to contain_docker__run('grafanarender') }
    it { is_expected.to contain_mysql_database('grafana') }
    it { is_expected.to contain_mysql_user('grafana@%') }
    it { is_expected.to contain_mysql_grant('grafana@%/grafana.*') }

    # Alertmanager
    it { is_expected.to contain_docker__run('alertmanager') }
    it { is_expected.to contain_file('/opt/alertmanager/config/alertmanager.yml') }
    it { is_expected.to contain_file('/opt/alertmanager/config/template') }
    it { is_expected.to contain_exec('alertmanager-config-reload').with_refreshonly(true) }

    # Ping Exporter
    it { is_expected.to contain_docker__run('ping-exporter') }

    # Loki
    it { is_expected.to contain_docker__run('loki') }
    it { is_expected.to contain_exec('loki-config-reload').with_refreshonly(true) }
  end

  context 'with retention and log_level' do
    let(:params) do
      super().merge(
        'prometheus_retention' => '90d',
        'prometheus_log_level' => 'debug',
      )
    end

    it { is_expected.to compile }
  end

  context 'with separate grafana network' do
    let(:params) do
      super().merge(
        'grafana_net' => 'grafana-net',
      )
    end

    it { is_expected.to compile }
    it {
      is_expected.to contain_docker__run('grafana').with(
        'net' => 'grafana-net',
      )
    }
  end
end
