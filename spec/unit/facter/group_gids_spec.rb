# frozen_string_literal: true

require 'spec_helper'
require 'facter'

describe 'group_gids' do
  before(:each) do
    Facter.clear
  end

  context 'when getent group succeeds' do
    it 'returns a hash of group names to GIDs' do
      getent_output = "root:x:0:\ndaemon:x:1:\nvideo:x:44:user1\n"
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return(getent_output)

      expect(Facter.value('group_gids')).to eq(
        'root' => 0,
        'daemon' => 1,
        'video' => 44,
      )
    end
  end

  context 'when getent group fails and /etc/group exists' do
    it 'falls back to reading /etc/group' do
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return(nil)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/group').and_return(true)
      allow(File).to receive(:read).with('/etc/group')
        .and_return("root:x:0:\nstaff:x:50:user1\n")

      expect(Facter.value('group_gids')).to eq(
        'root' => 0,
        'staff' => 50,
      )
    end
  end

  context 'when getent returns empty and /etc/group exists' do
    it 'falls back to reading /etc/group' do
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return('')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/group').and_return(true)
      allow(File).to receive(:read).with('/etc/group')
        .and_return("nobody:x:65534:\n")

      expect(Facter.value('group_gids')).to eq(
        'nobody' => 65_534,
      )
    end
  end

  context 'when neither getent nor /etc/group is available' do
    it 'returns an empty hash' do
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return(nil)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/group').and_return(false)

      expect(Facter.value('group_gids')).to eq({})
    end
  end

  context 'when /etc/group read raises an error' do
    it 'returns an empty hash' do
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return(nil)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/etc/group').and_return(true)
      allow(File).to receive(:read).with('/etc/group')
        .and_raise(Errno::EACCES)

      expect(Facter.value('group_gids')).to eq({})
    end
  end

  context 'when group file has malformed lines' do
    it 'skips lines with fewer than 3 fields' do
      getent_output = "root:x:0:\nbadline\nalso:bad\ngood:x:42:user\n"
      allow(Facter::Core::Execution).to receive(:execute)
        .with('getent group', on_fail: nil)
        .and_return(getent_output)

      expect(Facter.value('group_gids')).to eq(
        'root' => 0,
        'good' => 42,
      )
    end
  end
end
