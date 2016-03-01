Configuration ServiceConfig {
  Service UpdateDisable {
    Name = 'wuauserv'
    State = 'Stopped'
    StartupType = 'Disabled'
  }
  #Service FirewallDisable {
  #  Name = 'WinDefend'
  #  State = 'Stopped'
  #  StartupType = 'Disabled'
  #}
  #Service PuppetDisable {
  #  Name = 'puppet'
  #  State = 'Stopped'
  #  StartupType = 'Disabled'
  #}
}
