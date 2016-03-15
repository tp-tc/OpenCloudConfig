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
    GetScript = { @{ Result = ((Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--list-keys', 'releng-puppet-mail@mozilla.com') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-list-keys.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-list-keys.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))).ExitCode -eq 0) } }
    SetScript = {
      # todo: pipe key to gpg import, avoiding disk write
      Start-Process ('{0}\System32\diskperf.exe' -f $env:SystemRoot) -ArgumentList '-y' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.diskperf.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.diskperf.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      [IO.File]::WriteAllLines(('{0}\private.key' -f $env:Temp), [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)-----BEGIN PGP PRIVATE KEY BLOCK-----.*-----END PGP PRIVATE KEY BLOCK-----').Value)
      Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--allow-secret-key-import', '--import', ('{0}\private.key' -f $env:Temp)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-import-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-import-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Remove-Item -Path ('{0}\private.key' -f $env:Temp) -Force
    }
    TestScript = { if ((Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--list-keys', 'releng-puppet-mail@mozilla.com') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-list-keys.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-list-keys.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))).ExitCode -eq 0)  { $true } else { $false } }
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
      (New-Object Net.WebClient).DownloadFile('https://github.com/MozRelOps/OpenCloudConfig/blob/master/userdata/Configuration/smtp.pass.gpg?raw=true', ('{0}\smtp.pass.gpg' -f $env:Temp))
      $smtpPassword = (& ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) @('-d', ('{0}\smtp.pass.gpg' -f $env:Temp)))
      $credential = New-Object Management.Automation.PSCredential $smtpUsername, (ConvertTo-SecureString "$smtpPassword" -AsPlainText -Force)
      Remove-Item -Path ('{0}\smtp.pass.gpg' -f $env:Temp) -Force
      Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % {
        Remove-Item -Path $_.FullName -Force
      }
      $logFile = (Get-ChildItem -Path ('{0}\log' -f $env:SystemDrive) | Where-Object { !$_.PSIsContainer -and $_.Name.EndsWith('.userdata-run.log') } | Sort-Object LastAccessTime -Descending | Select-Object -First 1).FullName
      Start-Process ('{0}\7-Zip\7z.exe' -f $env:ProgramFiles) -ArgumentList @('a', $logFile.Replace('.log', '.zip'), ('{0}\log\*.log' -f $env:SystemDrive)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.zip-logs.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.zip-logs.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      $attachments = @($logFile.Replace('.log', '.zip'))
      Send-MailMessage -To $to -Subject $subject -Body ([IO.File]::ReadAllText($logfile)) -SmtpServer $smtpServer -Port $smtpPort -From $from -Attachments $attachments -UseSsl -Credential $credential
      Remove-Item -Path ('{0}\log\*.log' -f $env:SystemDrive) -Force      
    }
    TestScript = { $false }
  }
}
