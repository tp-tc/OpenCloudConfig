
# RegistryConfig sets or unsets registry values
Configuration RegistryConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  # https://bugzilla.mozilla.org/show_bug.cgi?id=1261812
  Registry ConsoleDefaultQuickEdit {
    Ensure = 'Present'
    Force = $true
    Hex = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps'
  }
  Registry ConsoleDefaultQuickEdit {
    Ensure = 'Present'
    Force = $true
    Hex = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
    ValueName = 'DontShowUI'
    ValueType = 'Dword'
    ValueData = '0x00000001' # on
  }

  # show file extensions by default
  Registry ExplorerFolderHideFileExtOff {
    Ensure = 'Present'
    Force = $true
    Hex = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\HideFileExt'
    ValueName = 'DefaultValue'
    ValueType = 'Dword'
    ValueData = '0x00000000'
  }
  # show full paths by default
  Registry ExplorerFolderShowFullPathOn {
    Ensure = 'Present'
    Force = $true
    Hex = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\ShowFullPath'
    ValueName = 'DefaultValue'
    ValueType = 'Dword'
    ValueData = '0x00000001'
  }
}
