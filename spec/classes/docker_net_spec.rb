require 'spec_helper'

describe 'shared_infra::docker_net' do
  context 'with default params' do
    it { is_expected.to compile }

    it {
      is_expected.to contain_docker_network('custom').with(
        'ensure'  => 'present',
        'driver'  => 'bridge',
        'subnet'  => '172.19.0.0/24',
        'gateway' => '172.19.0.1',
      )
    }
  end

  context 'with custom subnet' do
    let(:params) do
      {
        'custom_subnet'  => '10.99.0.0/24',
        'custom_gateway' => '10.99.0.1',
      }
    end

    it { is_expected.to compile }

    it {
      is_expected.to contain_docker_network('custom').with(
        'subnet'  => '10.99.0.0/24',
        'gateway' => '10.99.0.1',
      )
    }
  end
end
