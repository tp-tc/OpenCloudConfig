
# RegistryConfig sets or unsets registry values
Configuration RegistryConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1261812
  Registry WindowsErrorReportingLocalDumps {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
    ValueName = 'LocalDumps'
  }
  Registry WindowsErrorReportingDontShowUI {
    Ensure = 'Present'
    Force = $true
    Hex = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
    ValueName = 'DontShowUI'
    ValueType = 'Dword'
    ValueData = '0x00000001' # on
  }
}
