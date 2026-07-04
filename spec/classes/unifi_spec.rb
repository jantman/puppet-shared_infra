require 'spec_helper'

describe 'shared_infra::unifi' do
  let(:pre_condition) { 'include docker' }
  let(:required_params) do
    {
      'unpoller_unifi_url' => 'https://unifi.example.com:8443/',
      'unpoller_loki_url'  => 'http://loki:3100',
      'logs_loki_url'      => 'http://172.19.0.1:3100/loki/api/v1/push',
      'logs_loki_log_host' => 'testhost',
    }
  end

  context 'with required params' do
    let(:params) { required_params }

    it { is_expected.to compile }

    # User and group
    it { is_expected.to contain_group('unifi').with('gid' => 120, 'system' => true) }
    it { is_expected.to contain_user('unifi').with('uid' => 120, 'gid' => 'unifi', 'system' => true) }

    # MongoDB directories
    it { is_expected.to contain_file('/opt/unifi-mongodb').with('owner' => 999, 'group' => 999) }
    it { is_expected.to contain_file('/opt/unifi-mongodb/docker-entrypoint-initdb.d').with('owner' => 999) }
    it { is_expected.to contain_file('/opt/unifi-mongodb/data-db').with('owner' => 999) }
    it { is_expected.to contain_file('/opt/unifi-mongodb/backup').with('owner' => 999) }

    # init-mongo.js
    it {
      is_expected.to contain_file('/opt/unifi-mongodb/docker-entrypoint-initdb.d/init-mongo.js').with(
        'source' => 'puppet:///modules/shared_infra/unifi/init-mongo.js',
      )
    }

    # MongoDB container (defaults)
    it {
      is_expected.to contain_docker__run('unifi-mongodb').with(
        'image' => 'mongo:7.0.37-jammy',
        'net'   => 'custom',
      )
    }

    # Config dir
    it { is_expected.to contain_file('/opt/unifi8').with('owner' => 'unifi', 'group' => 'unifi') }
    it { is_expected.to contain_file('/opt/unifi8/resume_token.pkl').with('owner' => 'unifi') }

    # UniFi container
    it {
      is_expected.to contain_docker__run('unifi').with(
        'image' => 'lscr.io/linuxserver/unifi-network-application:10.4.57-ls135',
        'net'   => 'custom',
      )
    }

    # unPoller container
    it {
      is_expected.to contain_docker__run('unpoller').with(
        'net' => 'custom',
      )
    }

    # unifi-logs-loki container
    it {
      is_expected.to contain_docker__run('unifi-logs-loki').with(
        'net' => 'custom',
      )
    }

    # No firewall rules by default
    it { is_expected.not_to contain_firewall('600 accept UDP 3478 for unifi STUN') }
  end

  context 'with custom mongo and firewall' do
    let(:params) do
      required_params.merge(
        'mongo_image'    => 'mongo:4.4.18-focal',
        'mongo_command'  => '--replSet rs0 --bind_ip_all',
        'mongo_hostname' => 'unifi-mongodb',
        'manage_firewall' => true,
      )
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_docker__run('unifi-mongodb').with(
        'image'    => 'mongo:4.4.18-focal',
        'command'  => '--replSet rs0 --bind_ip_all',
        'hostname' => 'unifi-mongodb',
      )
    }

    it { is_expected.to contain_firewall('600 accept UDP 3478 for unifi STUN') }
    it { is_expected.to contain_firewall('601 accept TCP 8080 for unifi devices') }
    it { is_expected.to contain_firewall('602 accept TCP 8443 for unifi UI') }
    it { is_expected.to contain_firewall('603 accept TCP 6789 for unifi mobile speedtest') }
    it { is_expected.to contain_firewall('605 accept UDP 10001 for unifi discovery') }
    it { is_expected.to contain_firewall('606 accept UDP 5514 for unifi syslog') }
  end

  context 'with custom unpoller network' do
    let(:params) do
      required_params.merge(
        'unpoller_net'      => 'monitoring',
        'unpoller_save_dpi' => true,
      )
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_docker__run('unpoller').with(
        'net' => 'monitoring',
      )
    }
  end

  context 'with custom init_mongo_source' do
    let(:params) do
      required_params.merge(
        'init_mongo_source' => 'puppet:///modules/privatepuppet/unifi/docker-entrypoint-initdb.d/init-mongo.js',
      )
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_file('/opt/unifi-mongodb/docker-entrypoint-initdb.d/init-mongo.js').with(
        'source' => 'puppet:///modules/privatepuppet/unifi/docker-entrypoint-initdb.d/init-mongo.js',
      )
    }
  end

  context 'with extra_systemd_parameters' do
    let(:params) do
      required_params.merge(
        'extra_systemd_parameters' => {
          'ExecStartPost' => '/usr/local/bin/docker-net-add-when-up.sh unifi monitoring',
        },
      )
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_docker__run('unifi').with(
        'extra_systemd_parameters' => {
          'ExecStartPost' => '/usr/local/bin/docker-net-add-when-up.sh unifi monitoring',
        },
      )
    }
  end
end
