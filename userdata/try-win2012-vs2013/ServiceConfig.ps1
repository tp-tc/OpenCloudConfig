
# ServiceConfig installs, removes, disables or enables Windows Services
Configuration ServiceConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Service UpdateDisable {
    Name = 'wuauserv'
    State = 'Stopped'
    StartupType = 'Disabled'
  }
}
