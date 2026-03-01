# Disable automatic apt package updates for stability.
# Ensures updates happen only when explicitly triggered.
class shared_infra::disable_apt_daily {

  service {[
    'apt-daily.service', 'apt-daily.timer',
    'apt-daily-upgrade.timer', 'apt-daily-upgrade.service'
  ]:
    ensure => stopped,
    enable => false,
  }

}
