<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration MaintenanceToolChainConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  Chocolatey NxLogInstall {
    Ensure = 'Present'
    Package = 'nxlog'
    Version = '2.9.1504'
  }
  Script NxLogConfigure {
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

  Chocolatey SublimeText3Install {
    Ensure = 'Present'
    Package = 'sublimetext3'
    Version = '3.0.0.3103'
  }
  Chocolatey SublimeText3PackageControlInstall {
    Ensure = 'Present'
    Package = 'sublimetext3.packagecontrol'
    Version = '2.0.0.20140915'
  }

  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Script CygWinDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://www.cygwin.com/setup-x86_64.exe', ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp))
      Unblock-File -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp)
    }
    TestScript = { if (Test-Path -Path ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script CygWinInstall {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\cygwin\bin\cygrunsrv.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      Start-Process ('{0}\cygwin-setup-x86_64.exe' -f $env:Temp) -ArgumentList ('--quiet-mode --wait --root {0}\cygwin --site http://cygwin.mirror.constant.com --packages openssh,vim,curl,tar,wget,zip,unzip,diffutils,bzr' -f $env:SystemDrive) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.MozillaBuildSetup-2.1.0.exe.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { (Test-Path -Path ('{0}\cygwin\bin\cygrunsrv.exe' -f $env:SystemDrive)) }
  }
  Script SshInboundFirewallEnable {
    GetScript = { @{ Result = (Get-NetFirewallRule -DisplayName 'Allow SSH inbound' -ErrorAction SilentlyContinue) } }
    SetScript = { New-NetFirewallRule -DisplayName 'Allow SSH inbound' -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow }
    TestScript = { if (Get-NetFirewallRule -DisplayName 'Allow SSH inbound' -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script SshdPasswordGenerator {
    GetScript = { @{ Result = ("$env:SshdPassword" -ne "") } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('SshdPassword', [Guid]::NewGuid().ToString().Substring(0, 13), 'Process')
    }
    TestScript = { if ("$env:SshdPassword" -ne "") { $true } else { $false } }
  }
  User 'sshd' {
    UserName = 'sshd'
    Ensure = 'Present'
    FullName = 'SSH Service Account'
    Description = 'Used by the sshd Windows service'
    Password = (New-Object Management.Automation.PSCredential 'sshd', (ConvertTo-SecureString $env:SshdPassword -AsPlainText -Force))
    PasswordNeverExpires = $true
    PasswordChangeRequired = $false
    Disabled = $false
  }
  Script SshdServiceInstall {
    GetScript = { @{ Result = ((Get-Service 'sshd' -ErrorAction SilentlyContinue) -and ((Get-Service 'sshd').Status -eq 'running')) } }
    SetScript = {
      Start-Process ('{0}\cygwin\bin\bash.exe' -f $env:SystemDrive) -ArgumentList ("--login -c `"ssh-host-config -y -c 'ntsec mintty' -u 'sshd' -w '{0}'`"" -f $env:SshdPassword) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.ssh-host-config.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.ssh-host-config.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
    }
    TestScript = { if ((Get-Service 'sshd' -ErrorAction SilentlyContinue) -and ((Get-Service 'sshd').Status -eq 'running')) { $true } else { $false } }
  }
}
