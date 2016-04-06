<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration MaintenanceConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Script GpgKeyImport {
    DependsOn = '[File]LogFolder'
    GetScript = { @{ Result = (((Test-Path -Path ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)) -or ((Test-Path -Path ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb))) } }
    SetScript = {
      # todo: pipe key to gpg import, avoiding disk write
      Start-Process ('{0}\System32\diskperf.exe' -f $env:SystemRoot) -ArgumentList '-y' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.diskperf.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.diskperf.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      [IO.File]::WriteAllLines(('{0}\Temp\private.key' -f $env:SystemRoot), [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)-----BEGIN PGP PRIVATE KEY BLOCK-----.*-----END PGP PRIVATE KEY BLOCK-----').Value)
      Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--allow-secret-key-import', '--import', ('{0}\Temp\private.key' -f $env:SystemRoot)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-import-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-import-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Remove-Item -Path ('{0}\Temp\private.key' -f $env:SystemRoot) -Force
    }
    TestScript = { if (((Test-Path -Path ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\SysWOW64\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)) -or ((Test-Path -Path ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\System32\config\systemprofile\AppData\Roaming\gnupg\secring.gpg' -f $env:SystemRoot)).length -gt 0kb)))  { $true } else { $false } }
  }

  Script SendLogs {
    DependsOn = @('[File]LogFolder', '[Script]GpgKeyImport')
    GetScript = { @{ Result = $false } }
    SetScript = {
      # todo: move all this config to a config file
      $to = 'releng-puppet-mail@mozilla.com'
      $from = 'releng-puppet-mail@mozilla.com'
      $subject = ('UserData Run Report for TaskCluster worker: {0}' -f $env:ComputerName)
      $smtpServer = 'email-smtp.us-east-1.amazonaws.com'
      $smtpPort = 2587
      $smtpUsername = 'AKIAIPJEOD57YDLBF35Q'
      (New-Object Net.WebClient).DownloadFile('https://github.com/MozRelOps/OpenCloudConfig/blob/master/userdata/Configuration/smtp.pass.gpg?raw=true', ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot))
      Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('-d', ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\Temp\smtp.pass' -f $env:SystemRoot) -RedirectStandardError ('{0}\log\{1}.gpg-decrypt.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $smtpPassword = Get-Content ('{0}\Temp\smtp.pass' -f $env:SystemRoot)
      $credential = New-Object Management.Automation.PSCredential $smtpUsername, (ConvertTo-SecureString "$smtpPassword" -AsPlainText -Force)
      Remove-Item -Path ('{0}\Temp\smtp.pass' -f $env:SystemRoot) -Force
      Remove-Item -Path ('{0}\Temp\smtp.pass.gpg' -f $env:SystemRoot) -Force
      Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % {
        Remove-Item -Path $_.FullName -Force
      }
      $vs2013Log = (Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.vs_community_2013.exe.install.log') } | Sort-Object LastAccessTime -Descending | Select-Object -First 1).FullName
      if ($vs2013Log) {
        Start-Process ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ArgumentList @('a', $vs2013Log.Replace('.log', '.zip'), ('{0}*.log' -f $vs2013Log.Replace('.log', '_'))) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.zip-vs2013-logs.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.zip-vs2013-logs.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
        Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.FullName.StartsWith($vs2013Log.Replace('.log', '_')) -and $_.Name.EndsWith('.log') } | % {
          Remove-Item -Path $_.FullName -Force
        }
      }
      $vs2015Log = (Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.vs_community_2015.exe.install.log') } | Sort-Object LastAccessTime -Descending | Select-Object -First 1).FullName
      if ($vs2015Log) {
        Start-Process ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ArgumentList @('a', $vs2015Log.Replace('.log', '.zip'), ('{0}*.log' -f $vs2015Log.Replace('.log', '_'))) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.zip-vs2015-logs.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.zip-vs2015-logs.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
        Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.FullName.StartsWith($vs2015Log.Replace('.log', '_')) -and $_.Name.EndsWith('.log') } | % {
          Remove-Item -Path $_.FullName -Force
        }
      }
      $logFile = (Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.userdata-run.log') } | Sort-Object LastAccessTime -Descending | Select-Object -First 1).FullName
      Start-Process ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ArgumentList @('a', $logFile.Replace('.log', '.zip'), ('{0}\log\*.log' -f $env:SystemDrive)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.zip-logs.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.zip-logs.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $attachments = @($logFile.Replace('.log', '.zip'))
      $body = Get-Content -Path (-join @(Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.userdata-run.log') } | Sort-Object LastAccessTime -Ascending))
      Send-MailMessage -To $to -Subject $subject -Body $body -SmtpServer $smtpServer -Port $smtpPort -From $from -Attachments $attachments -UseSsl -Credential $credential
      Remove-Item -Path ('{0}\log\*.log' -f $env:SystemDrive) -Force
    }
    TestScript = { $false }
  }
}
