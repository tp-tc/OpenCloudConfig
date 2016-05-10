<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration MaintenanceToolChainConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Script OpenSshDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\OpenSSH-Win64.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://github.com/PowerShell/Win32-OpenSSH/releases/download/3_19_2016/OpenSSH-Win64.zip', ('{0}\Temp\OpenSSH-Win64.zip' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\OpenSSH-Win64.zip' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\OpenSSH-Win64.zip' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Archive OpenSshExtract {
    DependsOn = @('[Script]OpenSshDownload')
    Path = ('{0}\Temp\OpenSSH-Win64.zip' -f $env:SystemRoot)
    Destination = ('{0}' -f $env:ProgramFiles)
    Ensure = 'Present'
  }
  Script OpenSshFirewallEnable {
    GetScript = { @{ Result = (Get-NetFirewallRule -DisplayName 'SSH inbound: allow' -ErrorAction SilentlyContinue) } }
    SetScript = {
      New-NetFirewallRule -DisplayName 'SSH inbound: allow' -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow
      #netsh advfirewall firewall add rule name='Allow SSH inbound' dir=in action=allow protocol=TCP localport=22
    }
    TestScript = { if (Get-NetFirewallRule -DisplayName 'SSH inbound: allow' -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script OpenSshInstall {
    DependsOn = @('[Script]OpenSshFirewallEnable', '[Archive]OpenSshExtract', '[File]LogFolder')
    GetScript = { @{ Result = (Get-Service 'sshd' -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\OpenSSH-Win64\ssh-keygen.exe' -f $env:ProgramFiles) -ArgumentList @('-A') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.ssh-keygen.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.ssh-keygen.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Copy-Item -Path ('{0}\OpenSSH-Win64\ssh-lsa.dll' -f $env:ProgramFiles) -Destination ('{0}\System32' -f $env:SystemRoot)
      # enable key authentication
      $key = ([Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 0)).OpenSubKey('SYSTEM\CurrentControlSet\Control\Lsa', $true)
      $arr = $key.GetValue('Authentication Packages')
      if ($arr -notcontains 'ssh-lsa') {
        $arr += 'ssh-lsa' # 'msv1_0\0ssh-lsa.dll'
        $key.SetValue('Authentication Packages', [string[]]$arr, 'MultiString')
      }
      Start-Process ('{0}\OpenSSH-Win64\sshd.exe' -f $env:ProgramFiles) -ArgumentList @('install') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.sshd-install.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.sshd-install.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Set-Service sshd -StartupType Automatic
    }
    TestScript = { if (Get-Service 'sshd' -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}
