
# ServiceConfig installs, removes, disables or enables Windows Services
Configuration ServiceConfig {
  Service UpdateDisable {
    Name = 'wuauserv'
    State = 'Stopped'
    StartupType = 'Disabled'
  }
}
