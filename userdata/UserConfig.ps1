Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  $username = 'cltbld'
  try {
    $password = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), ('(?s)<{0}Password>(.*)</{0}Password>' -f $username)).Groups[1].Value
  } catch {
    $password = [Guid]::NewGuid().ToString().Substring(0, 13)
  }
  Script UserCreate {
    GetScript = "@{ UserCreate = $($username) }"
    SetScript = {
      $homedir = New-Item -Path ('{0}\Users' -f $env:SystemDrive) -Name $using:username -ItemType 'Directory'
      Start-Process 'net' -ArgumentList @('user', $using:username, $cltbldPassword, '/add', '/active:yes', '/expires:never', ('/homedir:{0}' -f $homedir.FullName), ('/profilepath:{0}' -f $homedir.FullName)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $username) -RedirectStandardError ('{0}\log\{1}.net-user-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $username)

      $fsr = [Security.AccessControl.FileSystemRights]"FullControl,Modify,ReadAndExecute,ListDirectory,Read,Write"
      $if = @([Security.AccessControl.InheritanceFlags]::ContainerInherit,[Security.AccessControl.InheritanceFlags]::ObjectInherit)
      $pf = [Security.AccessControl.PropagationFlags]::None
      $act = [Security.AccessControl.AccessControlType]::Allow
      $account = New-Object Security.Principal.NTAccount ('.\{0}' -f $using:username)
      $acl = Get-Acl -Path $homedir.FullName
      $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule ($account, $fsr, $if, $pf, $act)))
      Set-Acl -Path $homedir.FullName -AclObject $acl
    }
    TestScript = { if (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $using:username }) { $true } else { $false } }
  }
  Group AdministratorsMembers {
    DependsOn = '[Script]UserCreate'
    GroupName = 'Administrators'
    Ensure = 'Present'
    MembersToInclude = @($username)
  }
  Registry AutoAdminLogon {
    DependsOn = '[Script]UserCreate'
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
    ValueName = 'AutoAdminLogon'
    ValueType = 'Dword'
    Hex = $true
    ValueData = '0x00000001'
  }
  Registry DefaultDomainName {
    DependsOn = '[Script]UserCreate'
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
    ValueName = 'DefaultDomainName'
    ValueType = 'String'
    ValueData = '.'
  }
  Registry DefaultPassword {
    DependsOn = '[Script]UserCreate'
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
    ValueName = 'DefaultPassword'
    ValueType = 'String'
    ValueData = $password
  }
  Registry DefaultUserName {
    DependsOn = '[Script]UserCreate'
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
    ValueName = 'DefaultUserName'
    ValueType = 'String'
    ValueData = $username
  }
  Registry AutoLogonCount {
    DependsOn = '[Script]UserCreate'
    Ensure = 'Present'
    Force = $true
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon'
    ValueName = 'AutoLogonCount'
    ValueType = 'Dword'
    ValueData = '100000'
  }
  Script GenericWorkerAutoStart {
    DependsOn = '[Script]UserCreate'
    GetScript = { @{ Result = (Test-Path -Path ('C:\Users\{0}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\generic-worker.lnk' -f $username) -ErrorAction SilentlyContinue ) } }
    SetScript = {
      $sc = (New-Object -ComObject WScript.Shell).CreateShortcut(('C:\Users\{0}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\generic-worker.lnk' -f $username))
      $sc.TargetPath = "C:\generic-worker\generic-worker.exe --config C:\generic-worker\generic-worker.config"
      $sc.Save()
    }
    TestScript = { if (Test-Path -Path ('C:\Users\{0}\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\generic-worker.lnk' -f $username) -ErrorAction SilentlyContinue ) { $true } else { $false } }
    Credential = New-Object Management.Automation.PSCredential ($username, (ConvertTo-SecureString $password -AsPlainText -Force))
  }
  Script PowershellProfile {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Microsoft.PowerShell_profile.ps1', ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome))
      Unblock-File -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome)
      #Set-ItemProperty 'HKLM:\Software\Microsoft\Command Processor' -Type 'String' -Name 'AutoRun' -Value 'powershell -NoLogo -NonInteractive'
    }
    TestScript = { if (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) { $true } else { $false } }
  }
}