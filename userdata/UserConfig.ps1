
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script RootUserCreate {
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      & net @('user', 'root', [Guid]::NewGuid().ToString().Substring(0, 13), '/active:yes')
    }
    TestScript = { if (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) { $true } else { $false } }
  }
  Group RootAsAdministrator {
    DependsOn = '[Script]RootUserCreate'
    GroupName = 'Administrators'
    Ensure = 'Present'
    MembersToInclude = 'root'
  }
}
