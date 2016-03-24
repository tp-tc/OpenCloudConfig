
# RegistryConfig sets or unsets registry values
Configuration RegistryConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Registry ConsoleDefaultQuickEdit {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'QuickEdit'
    ValueType = 'REG_DWORD'
    ValueData = 0x00000001 # on
  }
  Registry ConsoleDefaultInsertMode {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'InsertMode'
    ValueType = 'REG_DWORD'
    ValueData = 0x00000001 # on
  }
  Registry ConsoleDefaultScreenBufferSize {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'ScreenBufferSize'
    ValueType = 'REG_DWORD'
    ValueData = 0x012c00a0 # 160x300
  }
  Registry ConsoleDefaultWindowSize {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'WindowSize'
    ValueType = 'REG_DWORD'
    ValueData = 0x003c00a0 # 160x60
  }
  Registry ConsoleDefaultHistoryBufferSize {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'HistoryBufferSize'
    ValueType = 'REG_DWORD'
    ValueData = 0x000003e7 # 999 (max)
  }
  Registry ConsoleDefaultScreenColors {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'ScreenColors'
    ValueType = 'REG_DWORD'
    ValueData = 0x0000000a # green on black
  }
  Registry ConsoleDefaultFontSize {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'FontSize'
    ValueType = 'REG_DWORD'
    ValueData = 0x000c0000 # 12
  }
  Registry ConsoleDefaultFontFamily {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'FontFamily'
    ValueType = 'REG_DWORD'
    ValueData = 0x00000036 # Consolas
  }
  Registry ConsoleDefaultFaceName {
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_USERS\.DEFAULT\Console'
    ValueName = 'FaceName'
    ValueType = 'REG_SZ'
    ValueData = 'Consolas'
  }
}
