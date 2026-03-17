# frozen_string_literal: true

# Custom fact: group_gids
# Returns a hash of all system groups mapped name => numeric GID
# Parsed from `getent group` or /etc/group

Facter.add('group_gids') do
  setcode do
    output = Facter::Core::Execution.execute('getent group', on_fail: nil)
    if output.nil? || output.empty?
      if File.exist?('/etc/group')
        begin
          output = File.read('/etc/group')
        rescue StandardError
          output = nil
        end
      end
    end

    if output.nil? || output.empty?
      {}
    else
      result = {}
      output.each_line do |line|
        parts = line.strip.split(':')
        next if parts.length < 3
        result[parts[0]] = parts[2].to_i
      end
      result
    end
  end
end
