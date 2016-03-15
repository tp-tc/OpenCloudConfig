
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  User Root {
    UserName = 'root'
    Description = 'Local admin with a familiar name'
    Ensure = 'Present'
    FullName = 'Local Administrator'
    Password = [Guid]::NewGuid().ToString().Substring(0, 13)
    PasswordChangeRequired = $false
    PasswordNeverExpires = $true
  }
  Group RootAsAdministrator {
    GroupName = 'Administrators'
    DependsOn = '[User]Root'
    Ensure = 'Present'
    MembersToInclude = 'root'
  }
}
