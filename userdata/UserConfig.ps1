Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script RootUserCreate {
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      $password = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)<rootPassword>(.*)</rootPassword>').Groups[1].Value
      if (!$password) {
        $password = [Guid]::NewGuid().ToString().Substring(0, 13)
      }
      Start-Process 'net' -ArgumentList @('user', 'root', $password, '/ADD', '/active:yes', '/expires:never') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-root.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-root.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Job -ScriptBlock {

        # ssh authorized_keys
        New-Item ('{0}\.ssh' -f $env:UserProfile) -type directory -force
        (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/authorized_keys', ('{0}\.ssh\authorized_keys' -f $env:UserProfile))
        Unblock-File -Path ('{0}\.ssh\authorized_keys' -f $env:UserProfile)
        
      } -Credential (New-Object Management.Automation.PSCredential 'root', (ConvertTo-SecureString "$password" -AsPlainText -Force))
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
  Script PowershellProfile {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Microsoft.PowerShell_profile.ps1', ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome))
      Unblock-File -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome)
      Set-ItemProperty 'HKLM:\Software\Microsoft\Command Processor' -Type 'String' -Name 'AutoRun' -Value 'powershell -NoLogo -NonInteractive'
    }
    TestScript = { if (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) { $true } else { $false } }
  }
}