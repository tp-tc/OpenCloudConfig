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

  Script NxLogDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\nxlog-ce-2.9.1504.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://nxlog.org/system/files/products/files/1/nxlog-ce-2.9.1504.msi', ('{0}\Temp\nxlog-ce-2.9.1504.msi' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\nxlog-ce-2.9.1504.msi' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\nxlog-ce-2.9.1504.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Package NxLogInstall {
    DependsOn = @('[Script]NxLogDownload', '[File]LogFolder')
    Name = 'NxLog-CE'
    Path = ('{0}\Temp\nxlog-ce-2.9.1504.msi' -f $env:SystemRoot)
    ProductId = '5E1D25F5-647E-44CA-9223-387230EC02C6'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.nxlog-ce-2.9.1504.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script NxLogConfigure {
    DependsOn = '[Package]NxLogInstall'
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\nxlog\cert\papertrail-bundle.pem' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) -and (((Get-Content ('{0}\nxlog\conf\nxlog.conf' -f ${env:ProgramFiles(x86)})) | %{ $_ -match 'papertrail-bundle.pem' }) -contains $true) -and (Get-Service 'nxlog' -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://papertrailapp.com/tools/papertrail-bundle.pem', ('{0}\nxlog\cert\papertrail-bundle.pem' -f ${env:ProgramFiles(x86)}))
      Unblock-File -Path ('{0}\nxlog\cert\papertrail-bundle.pem' -f ${env:ProgramFiles(x86)})
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/nxlog.conf', ('{0}\nxlog\conf\nxlog.conf' -f ${env:ProgramFiles(x86)}))
      Unblock-File -Path ('{0}\nxlog\conf\nxlog.conf' -f ${env:ProgramFiles(x86)})
      Restart-Service nxlog
    }
    TestScript = { if ((Test-Path -Path ('{0}\nxlog\cert\papertrail-bundle.pem' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) -and (((Get-Content ('{0}\nxlog\conf\nxlog.conf' -f ${env:ProgramFiles(x86)})) | %{ $_ -match 'papertrail-bundle.pem' }) -contains $true) -and (Get-Service 'nxlog' -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }

  Script SublimeText3Download {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if (Test-Path ${env:ProgramFiles(x86)} -ErrorAction SilentlyContinue) {
        (New-Object Net.WebClient).DownloadFile('https://download.sublimetext.com/Sublime%20Text%20Build%203103%20x64%20Setup.exe', ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot))
      } else {
        (New-Object Net.WebClient).DownloadFile('https://download.sublimetext.com/Sublime%20Text%20Build%203103%20Setup.exe', ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot))
      }
      Unblock-File -Path ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script SublimeText3Install {
    DependsOn = @('[Script]SublimeText3Download', '[File]LogFolder')
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\Sublime Text 3\subl.exe'-f $env:ProgramFiles) -ErrorAction SilentlyContinue) -and ((& ('{0}\Sublime Text 3\subl.exe'-f $env:ProgramFiles) '--version') -ieq 'Sublime Text Build 3103')) } }
    SetScript = {
      Start-Process ('{0}\Temp\sublime-text-setup.exe' -f $env:SystemRoot) -ArgumentList '/VERYSILENT /NORESTART /TASKS="contextentry"' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.sublime-text-setup.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.sublime-text-setup.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Get-ChildItem -Path ('{0}\Users' -f $env:SystemDrive) | Where-Object { $_.PSIsContainer } | % {
        if (Test-Path -Path ('{0}\AppData\Roaming' -f $_.FullName) -ErrorAction SilentlyContinue) {
          New-Item ('{0}\AppData\Roaming\Sublime Text 3\Packages' -f $_.FullName) -type directory -force
          (New-Object Net.WebClient).DownloadFile('http://sublime.wbond.net/Package%20Control.sublime-package', ('{0}\AppData\Roaming\Sublime Text 3\Packages\Package Control.sublime-package' -f $_.FullName))
          Unblock-File -Path ('{0}\AppData\Roaming\Sublime Text 3\Packages\Package Control.sublime-package' -f $_.FullName)
        }
      }
    }
    TestScript = { if ((Test-Path -Path ('{0}\Sublime Text 3\subl.exe'-f $env:ProgramFiles) -ErrorAction SilentlyContinue) -and ((& ('{0}\Sublime Text 3\subl.exe'-f $env:ProgramFiles) '--version') -ieq 'Sublime Text Build 3103')) { $true } else { $false } }
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

  Script GpgForWinDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\gpg4win-2.3.0.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://files.gpg4win.org/gpg4win-2.3.0.exe', ('{0}\Temp\gpg4win-2.3.0.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\gpg4win-2.3.0.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\gpg4win-2.3.0.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script GpgForWinInstall {
    DependsOn = '[Script]GpgForWinDownload'
    GetScript = { @{ Result = (Test-Path -Path ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Temp\gpg4win-2.3.0.exe' -f $env:SystemRoot) -ArgumentList '/S' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg4win-2.3.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg4win-2.3.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { (Test-Path -Path ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ErrorAction SilentlyContinue) }
  }

  Script SevenZipDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\7z1514-x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('http://7-zip.org/a/7z1514-x64.exe', ('{0}\Temp\7z1514-x64.exe' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\7z1514-x64.exe' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\7z1514-x64.exe' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script SevenZipInstall {
    DependsOn = '[Script]SevenZipDownload'
    GetScript = { @{ Result = (Test-Path -Path ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\Temp\7z1514-x64.exe' -f $env:SystemRoot) -ArgumentList ('/S' -f $env:SystemDrive) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.7z1514-x64.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.7z1514-x64.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if (Test-Path -Path ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}
