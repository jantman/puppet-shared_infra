require 'spec_helper'

describe 'shared_infra::base' do
  it { is_expected.to compile }

  it { is_expected.to contain_file('/root/bin').with_ensure('directory') }

  it {
    is_expected.to contain_exec('systemd-reload').with(
      'command'     => 'systemctl daemon-reload',
      'refreshonly' => true,
    )
  }
end
