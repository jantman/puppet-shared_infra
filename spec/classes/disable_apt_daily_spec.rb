require 'spec_helper'

describe 'shared_infra::disable_apt_daily' do
  it { is_expected.to compile }

  ['apt-daily.service', 'apt-daily.timer',
   'apt-daily-upgrade.timer', 'apt-daily-upgrade.service'].each do |svc|
    it {
      is_expected.to contain_service(svc).with(
        'ensure' => 'stopped',
        'enable' => 'false',
      )
    }
  end
end
