
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script RootUserCreate {
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      $password = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)<rootPassword>(.*)</rootPassword>').Groups[1].Value
      if (!$password) {
        $password = [Guid]::NewGuid().ToString().Substring(0, 13)
      }
      & net @('user', 'root', $password, '/ADD', '/active:yes', '/expires:never')
      #& icacls @(('{0}\Users\root' -f $env:SystemDrive), '/T', '/C', '/grant', 'Administrators:(F)')
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
