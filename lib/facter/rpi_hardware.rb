# frozen_string_literal: true

# Custom facts for Raspberry Pi hardware information
# Parses /proc/cpuinfo and /proc/meminfo to extract RPi-specific details

def read_proc_cpuinfo
  return nil unless File.exist?('/proc/cpuinfo')
  File.read('/proc/cpuinfo')
rescue StandardError
  nil
end

def read_proc_meminfo
  return nil unless File.exist?('/proc/meminfo')
  File.read('/proc/meminfo')
rescue StandardError
  nil
end

# Parse Raspberry Pi model from /proc/cpuinfo
Facter.add('rpi_model') do
  setcode do
    cpuinfo = read_proc_cpuinfo
    next nil if cpuinfo.nil?

    match = cpuinfo.match(/^Model\s*:\s*(.+)$/)
    match[1].strip if match
  end
end

# Parse Raspberry Pi serial number from /proc/cpuinfo
Facter.add('rpi_serial') do
  setcode do
    cpuinfo = read_proc_cpuinfo
    next nil if cpuinfo.nil?

    match = cpuinfo.match(/^Serial\s*:\s*(.+)$/)
    match[1].strip if match
  end
end

# Parse Raspberry Pi revision from /proc/cpuinfo
Facter.add('rpi_revision') do
  setcode do
    cpuinfo = read_proc_cpuinfo
    next nil if cpuinfo.nil?

    match = cpuinfo.match(/^Revision\s*:\s*(.+)$/)
    match[1].strip if match
  end
end

# Parse total memory in MB from /proc/meminfo
Facter.add('rpi_memory_mb') do
  setcode do
    meminfo = read_proc_meminfo
    next nil if meminfo.nil?

    match = meminfo.match(/^MemTotal:\s+(\d+)\s+kB/)
    if match
      kb = match[1].to_i
      # Convert kB to MB (rounded)
      (kb / 1024.0).round
    end
  end
end

# Boolean fact to indicate if this is a Raspberry Pi
Facter.add('is_rpi') do
  setcode do
    cpuinfo = read_proc_cpuinfo
    next false if cpuinfo.nil?

    # Check if the Model line contains "Raspberry Pi"
    cpuinfo.match?(/^Model\s*:\s*Raspberry Pi/i)
  end
end
