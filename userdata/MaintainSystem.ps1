<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>

function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'MaintainSystem',
    [string] $logName = 'Application'
  )
  if (!([Diagnostics.EventLog]::Exists($logName)) -or !([Diagnostics.EventLog]::SourceExists($source))) {
    New-EventLog -LogName $logName -Source $source
  }
  switch ($severity) {
    'DEBUG' {
      $entryType = 'SuccessAudit'
      $eventId = 2
      break
    }
    'WARN' {
      $entryType = 'Warning'
      $eventId = 3
      break
    }
    'ERROR' {
      $entryType = 'Error'
      $eventId = 4
      break
    }
    default {
      $entryType = 'Information'
      $eventId = 1
      break
    }
  }
  Write-EventLog -LogName $logName -Source $source -EntryType $entryType -Category 0 -EventID $eventId -Message $message
  if ([Environment]::UserInteractive) {
    $fc = @{ 'Information' = 'White'; 'Error' = 'Red'; 'Warning' = 'DarkYellow'; 'SuccessAudit' = 'DarkGray' }[$entryType]
    Write-Host -object $message -ForegroundColor $fc
  }
}
function Run-MaintainSystem {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    Remove-OldTaskDirectories
    Disable-DesiredStateConfig
    if (${env:PROCESSOR_ARCHITEW6432} -eq 'ARM64') {
      Invoke-OccReset -sourceOrg 'mozilla-releng' -sourceRepo 'OpenCloudConfig' -sourceRev 'master'
    } else {
      Invoke-OccReset
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Remove-OldTaskDirectories {
  param (
    [string[]] $targets = @('Z:\task_*', 'C:\Users\task_*')
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    foreach ($target in ($targets | ? { (Test-Path -Path ('{0}:\' -f $_[0]) -ErrorAction SilentlyContinue) })) {
      $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.CreationTime })
      # https://bugzil.la/1543490
      # Retain the _two_ most recently created task folders, since one is for
      # the currently running task, and one is already prepared for the
      # subsequent task after the next reboot.
      if ($all_task_paths.length -gt 2) {
        Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
        # Note, arrays are zero-based, so the last entry for deletion when
        # keeping two folders is actually $all_task_paths.Length-3.
        $old_task_paths = $all_task_paths[0..($all_task_paths.Length-3)]
        foreach ($old_task_path in $old_task_paths) {
          try {
            & takeown.exe @('/a', '/f', $old_task_path, '/r', '/d', 'Y')
            & icacls.exe @($old_task_path, '/grant', 'Administrators:F', '/t')
            Remove-Item -Path $old_task_path -Force -Recurse
            Write-Log -message ('{0} :: removed task directory: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime) -severity 'INFO'
          } catch {
            Write-Log -message ('{0} :: failed to remove task directory: {1}, with last write time: {2}. {3}' -f $($MyInvocation.MyCommand.Name), $old_task_path.FullName, $old_task_path.LastWriteTime, $_.Exception.Message) -severity 'ERROR'
          }
        }
      } elseif ($all_task_paths.length -eq 1) {
        Write-Log -message ('{0} :: a single task directory was detected at: {1}, with last write time: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths[0].FullName, $all_task_paths[0].LastWriteTime) -severity 'DEBUG'
      } else {
        Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f$($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
      }
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Invoke-OccReset {
  param (
    [string] $sourceOrg = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Organisation' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Organisation').Organisation } else { 'mozilla-releng' }),
    [string] $sourceRepo = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Repository' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Repository').Repository } else { 'OpenCloudConfig' }),
    [string] $sourceRev = $(if ((Test-Path -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -ErrorAction SilentlyContinue) -and (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Revision' -ErrorAction SilentlyContinue)) { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Name 'Revision').Revision } else { 'master' })
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w1064-') -or (${env:PROCESSOR_ARCHITEW6432} -eq 'ARM64')) {
        foreach ($script in @('rundsc', 'MaintainSystem')) {
          $guid = [Guid]::NewGuid()
          $scriptUrl = ('https://raw.githubusercontent.com/{0}/{1}/{2}/userdata/{3}.ps1?{4}' -f $sourceOrg, $sourceRepo, $sourceRev, $script, $guid)
          $newScriptPath = ('C:\dsc\{0}-{1}.ps1' -f $script, $guid)
          try {
            (New-Object Net.WebClient).DownloadFile($scriptUrl, $newScriptPath)
          } catch {
            Write-Log -message ('{0} :: error downloading {1} to {2}. {3}' -f $($MyInvocation.MyCommand.Name), $scriptUrl, $newScriptPath, $_.Exception.Message) -severity 'ERROR'
          }
          if (Test-Path -Path $newScriptPath -ErrorAction SilentlyContinue) {
            $oldScriptPath = ('C:\dsc\{0}.ps1' -f $script)
            if (Test-Path -Path $oldScriptPath -ErrorAction SilentlyContinue) {
              $newSha512Hash = (Get-FileHash -Path $newScriptPath -Algorithm 'SHA512').Hash
              $oldSha512Hash = (Get-FileHash -Path $oldScriptPath -Algorithm 'SHA512').Hash

              if ($newSha512Hash -ne $oldSha512Hash) {
                Write-Log -message ('{0} :: {1} hashes do not match (old: {2}, new: {3})' -f $($MyInvocation.MyCommand.Name), $script, ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'INFO'
                Remove-Item -Path $oldScriptPath -force -ErrorAction SilentlyContinue
                Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
              } else {
                Write-Log -message ('{0} :: {1} hashes match (old: {2}, new: {3})' -f $($MyInvocation.MyCommand.Name), $script, ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'DEBUG'
                Remove-Item -Path $newScriptPath -force -ErrorAction SilentlyContinue
              }
            } else {
              Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
              Write-Log -message ('{0} :: existing {1} not found. downloaded {1} applied' -f $($MyInvocation.MyCommand.Name), $script) -severity 'INFO'
            }
          } else {
            Write-Log -message ('{0} :: comparison skipped for {1}' -f $($MyInvocation.MyCommand.Name), $script) -severity 'INFO'
          }
        }
      }
      if (${env:PROCESSOR_ARCHITEW6432} -eq 'ARM64') {
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Mozilla\OpenCloudConfig\Source' -Type 'String' -Name 'Revision' -Value 'master'
        if ((Test-Path -Path 'C:\generic-worker\generic-worker.config' -ErrorAction SilentlyContinue) -and (-not (Test-Path -Path 'C:\generic-worker\master-generic-worker.json' -ErrorAction SilentlyContinue))) {
          Copy-Item -Path 'C:\generic-worker\generic-worker.config' -Destination 'C:\generic-worker\master-generic-worker.json'
        }
        if ((Test-Path -Path ('{0}\Mozilla\OpenCloudConfig\OpenCloudConfig.private.key' -f $env:ProgramData) -ErrorAction SilentlyContinue) -and (-not ((Test-Path -Path ('{0}\gnupg\secring.gpg' -f $env:AppData) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\gnupg\secring.gpg' -f $env:AppData)).length -gt 0kb)))) {
          Start-Process 'diskperf.exe' -ArgumentList '-y' -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.diskperf.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.diskperf.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
          Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--allow-secret-key-import', '--import', ('{0}\Mozilla\OpenCloudConfig\OpenCloudConfig.private.key' -f $env:ProgramData)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.gpg-import-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.gpg-import-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
        }
        if ((Test-Path -Path ('{0}\gnupg\secring.gpg' -f $env:AppData) -ErrorAction SilentlyContinue) -and ((Get-Item ('{0}\gnupg\secring.gpg' -f $env:AppData)).length -gt 0kb)) {
          Write-Log -message ('{0} :: gpg keyring detected' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          New-Item -Path 'C:\builds' -ItemType Directory -ErrorAction SilentlyContinue
          New-Item -Path ('{0}\Mozilla\OpenCloudConfig' -f $env:ProgramData) -ItemType Directory -ErrorAction SilentlyContinue
          [hashtable] $resources = @{
            'C:\builds\taskcluster-worker-ec2@aws-stackdriver-log-1571127027.json' = 'https://s3.amazonaws.com/windows-opencloudconfig-packages/FirefoxBuildResources/taskcluster-worker-ec2@aws-stackdriver-log-1571127027.json.gpg?raw=true';
            'C:\builds\relengapi.tok' = 'https://s3.amazonaws.com/windows-opencloudconfig-packages/FirefoxBuildResources/relengapi.tok.gpg?raw=true';
            'C:\builds\occ-installers.tok' = 'https://s3.amazonaws.com/windows-opencloudconfig-packages/FirefoxBuildResources/occ-installers.tok.gpg?raw=true';
            ('{0}\Mozilla\OpenCloudConfig\project_releng_generic-worker_bitbar-gecko-t-win10-aarch64.txt' -f $env:ProgramData) = 'https://gist.github.com/grenade/dfbf31ef54bb6a0191fc386240bb71e7/raw/project_releng_generic-worker_bitbar-gecko-t-win10-aarch64.txt.gpg'
          }
          foreach ($localPath in $resources.Keys) {
            $downloadUrl = $resources.Item($localPath)
            if (-not (Test-Path -Path $localPath -ErrorAction SilentlyContinue)) {
              try {
                (New-Object Net.WebClient).DownloadFile($downloadUrl, ('{0}.gpg' -f $localPath))
              } catch {
                Write-Log -message ('{0} :: error downloading {1} to {2}. {3}' -f $($MyInvocation.MyCommand.Name), $downloadUrl, ('{0}.gpg' -f $localPath), $_.Exception.Message) -severity 'ERROR'
              }
              if (Test-Path -Path ('{0}.gpg' -f $localPath) -ErrorAction SilentlyContinue) {
                Write-Log -message ('{0} :: {1} downloaded from {2}' -f $($MyInvocation.MyCommand.Name), ('{0}.gpg' -f $localPath), $downloadUrl) -severity 'INFO'
                Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('-d', ('{0}.gpg' -f $localPath)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $localPath -RedirectStandardError ('{0}\log\{1}.gpg-decrypt-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), [IO.Path]::GetFileNameWithoutExtension($localPath))
                if (Test-Path -Path $localPath -ErrorAction SilentlyContinue) {
                  Write-Log -message ('{0} :: decrypted {1} to {2}' -f $($MyInvocation.MyCommand.Name), ('{0}.gpg' -f $localPath), $localPath) -severity 'INFO'
                }
                Remove-Item -Path ('{0}.gpg' -f $localPath) -Force
                Write-Log -message ('{0} :: deleted "{1}"' -f $($MyInvocation.MyCommand.Name), ('{0}.gpg' -f $localPath))
              }
            } else {
              Write-Log -message ('{0} :: detected {1}. skipping download from {2}' -f $($MyInvocation.MyCommand.Name), $localPath, $downloadUrl) -severity 'DEBUG'
            }
          }
        } else {
          Write-Log -message ('{0} :: gpg keyring not found' -f $($MyInvocation.MyCommand.Name)) -severity 'ERROR'
        }
        if (-not (Test-Path -Path ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData) -ErrorAction SilentlyContinue)) {
          New-Item -Path ('{0}\Mozilla\OpenCloudConfig' -f $env:ProgramData) -ItemType Directory -ErrorAction SilentlyContinue
          $gpgKeyGenConfigPath = ('{0}\Mozilla\OpenCloudConfig\gpg-keygen-config.txt' -f $env:ProgramData)
          [IO.File]::WriteAllLines($gpgKeyGenConfigPath, @(
            'Key-Type: eddsa',
            'Key-Curve: Ed25519',
            'Key-Usage: cert',
            'Subkey-Type: ecdh',
            'Subkey-Curve: Curve25519',
            'Subkey-Usage: encrypt',
            'Expire-Date: 0',
            ('Name-Real: {0} {1}' -f $env:USERNAME, [System.Net.Dns]::GetHostName()),
            ('Name-Email: {0}@{1}' -f $env:USERNAME, [System.Net.Dns]::GetHostName()),
            '%no-protection',
            '%commit',
            '%echo done'
          ), (New-Object -TypeName 'System.Text.UTF8Encoding' -ArgumentList $false))
          if (Test-Path -Path $gpgKeyGenConfigPath -ErrorAction SilentlyContinue) {
            Write-Log -message ('{0} :: {1} created' -f $($MyInvocation.MyCommand.Name), $gpgKeyGenConfigPath) -severity 'DEBUG'

            $gpgBatchGenerateKeyStdOutPath = ('{0}\log\{1}.gpg-batch-generate-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
            $gpgBatchGenerateKeyStdErrPath = ('{0}\log\{1}.gpg-batch-generate-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
            Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--batch', '--full-gen-key', ('{0}\Mozilla\OpenCloudConfig\gpg-keygen-config.txt' -f $env:ProgramData)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $gpgBatchGenerateKeyStdOutPath -RedirectStandardError $gpgBatchGenerateKeyStdErrPath
            if ((Get-Item -Path $gpgBatchGenerateKeyStdErrPath).Length -gt 0kb) {
              Write-Log -message ('{0} :: {1}' -f $($MyInvocation.MyCommand.Name), (Get-Content -Path $gpgBatchGenerateKeyStdErrPath -Raw)) -severity 'ERROR'
            } else {
              Write-Log -message ('{0} :: {1}' -f $($MyInvocation.MyCommand.Name), (Get-Content -Path $gpgBatchGenerateKeyStdOutPath -Raw)) -severity 'INFO'
              $gpgArmorExportPubKeyStdOutPath = ('{0}\log\{1}.gpg-armor-export-public-key.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
              $gpgArmorExportPubKeyStdErrPath = ('{0}\log\{1}.gpg-armor-export-public-key.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
              Start-Process ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)}) -ArgumentList @('--armor', '--output', ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData), '--export', ('{0}@{1}' -f $env:USERNAME, [System.Net.Dns]::GetHostName())) -Wait -NoNewWindow -PassThru -RedirectStandardOutput $gpgArmorExportPubKeyStdOutPath -RedirectStandardError $gpgArmorExportPubKeyStdErrPath
              if ((Get-Item -Path $gpgArmorExportPubKeyStdErrPath).Length -gt 0kb) {
                Write-Log -message ('{0} :: {1}' -f $($MyInvocation.MyCommand.Name), (Get-Content -Path $gpgArmorExportPubKeyStdErrPath -Raw)) -severity 'ERROR'
              } else {
                Write-Log -message ('{0} :: {1}' -f $($MyInvocation.MyCommand.Name), (Get-Content -Path $gpgArmorExportPubKeyStdOutPath -Raw)) -severity 'INFO'
              }
            }
          } else {
            Write-Log -message ('{0} :: error: {1} not created' -f $($MyInvocation.MyCommand.Name), $gpgKeyGenConfigPath) -severity 'ERROR'
          }
        }
        if (Test-Path -Path ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData) -ErrorAction SilentlyContinue) {
          Write-Log -message ('{0} :: gpg public key found at: {1}' -f $($MyInvocation.MyCommand.Name), ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData)) -severity 'DEBUG'
          $publicKey = (Get-Content -Path ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData) -Raw)
          Write-Log -message ('{0} :: {1}' -f $($MyInvocation.MyCommand.Name), $publicKey) -severity 'DEBUG'
        } else {
          Write-Log -message ('{0} :: gpg public key not found at: {1}' -f $($MyInvocation.MyCommand.Name), ('{0}\Mozilla\OpenCloudConfig\occ-public.key' -f $env:ProgramData)) -severity 'ERROR'
        }
        # todo: generate C:\generic-worker\ed25519-private.key and C:\generic-worker\ed25519-public.key
      }
      if ((${env:PROCESSOR_ARCHITEW6432} -eq 'ARM64') -and (-not (Test-ScheduledTaskExists -TaskName 'RunDesiredStateConfigurationAtStartup'))) {
        New-PowershellScheduledTask -taskName 'RunDesiredStateConfigurationAtStartup' -scriptUrl ('https://raw.githubusercontent.com/{0}/{1}/{2}/userdata/rundsc.ps1?{3}' -f $sourceOrg, $sourceRepo, $sourceRev, [Guid]::NewGuid()) -scriptPath 'C:\dsc\rundsc.ps1' -sc 'onstart'
      }
    } catch {
      Write-Log -message ('{0} :: exception - {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Test-ScheduledTaskExists {
  param (
    [string] $taskName
  )
  if (Get-Command 'Get-ScheduledTask' -ErrorAction 'SilentlyContinue') {
    return [bool](Get-ScheduledTask -TaskName $taskName -ErrorAction 'SilentlyContinue')
  }
  # sceduled task commandlets are unavailable on windows 7, so we use com to access sceduled tasks here.
  $scheduleService = (New-Object -ComObject Schedule.Service)
  $scheduleService.Connect()
  return (@($scheduleService.GetFolder("\").GetTasks(0) | ? { $_.Name -eq $taskName }).Length -gt 0)
}
function New-PowershellScheduledTask {
  param (
    [string] $taskName,
    [string] $scriptUrl,
    [string] $scriptPath,
    [string] $sc,
    [string] $mo = $null
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    # delete scheduled task if it pre-exists
    if ((Test-ScheduledTaskExists -TaskName $taskName)) {
      try {
        Start-Process 'schtasks.exe' -ArgumentList @('/delete', '/tn', $taskName, '/f') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.schtask-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName) -RedirectStandardError ('{0}\log\{1}.schtask-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName)
        Write-Log -message ('{0} :: scheduled task: {1} deleted.' -f $($MyInvocation.MyCommand.Name), $taskName) -severity 'INFO'
      }
      catch {
        Write-Log -message ('{0} :: failed to delete scheduled task: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $taskName, $_.Exception.Message) -severity 'ERROR'
      }
    }
    # delete script if it pre-exists
    if (Test-Path -Path $scriptPath -ErrorAction SilentlyContinue) {
      Remove-Item -Path $scriptPath -confirm:$false -force
      Write-Log -message ('{0} :: {1} deleted.' -f $($MyInvocation.MyCommand.Name), $scriptPath) -severity 'INFO'
    }
    # download script
    try {
      (New-Object Net.WebClient).DownloadFile($scriptUrl, $scriptPath)
      Write-Log -message ('{0} :: {1} downloaded from {2}.' -f $($MyInvocation.MyCommand.Name), $scriptPath, $scriptUrl) -severity 'INFO'
    }
    catch {
      Write-Log -message ('{0} :: failed to download scheduled task script {1} from {2}. {3}' -f $($MyInvocation.MyCommand.Name), $scriptPath, $scriptUrl, $_.Exception.Message) -severity 'ERROR'
    }
    if (Test-Path -Path $scriptPath -ErrorAction SilentlyContinue) {
      # create scheduled task
      try {
        if ($mo) {
          Start-Process 'schtasks.exe' -ArgumentList @('/create', '/tn', $taskName, '/sc', $sc, '/mo', $mo, '/ru', 'SYSTEM', '/rl', 'HIGHEST', '/tr', ('"{0}\powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -File \"{1}\" -ExecutionPolicy RemoteSigned -ConsoleOutputFile \"{2}\" "' -f $pshome, $scriptPath, $scriptPath.Replace('.ps1', '-run.log')), '/f') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.schtask-{2}-create.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName) -RedirectStandardError ('{0}\log\{1}.schtask-{2}-create.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName)
        } else {
          Start-Process 'schtasks.exe' -ArgumentList @('/create', '/tn', $taskName, '/sc', $sc, '/ru', 'SYSTEM', '/rl', 'HIGHEST', '/tr', ('"{0}\powershell.exe -NoLogo -NoProfile -WindowStyle Hidden -File \"{1}\" -ExecutionPolicy RemoteSigned -ConsoleOutputFile \"{2}\" "' -f $pshome, $scriptPath, $scriptPath.Replace('.ps1', '-run.log')), '/f') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.schtask-{2}-create.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName) -RedirectStandardError ('{0}\log\{1}.schtask-{2}-create.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $taskName)
        }
        Write-Log -message ('{0} :: scheduled task: {1} created.' -f $($MyInvocation.MyCommand.Name), $taskName) -severity 'INFO'
      }
      catch {
        Write-Log -message ('{0} :: failed to create scheduled task: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $taskName, $_.Exception.Message) -severity 'ERROR'
      }
    } else {
      Write-Log -message ('{0} :: skipped creation of scheduled task: {1}. missing script: {2}' -f $($MyInvocation.MyCommand.Name), $taskName, $scriptPath) -severity 'ERROR'
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
function Disable-DesiredStateConfig {
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w1064-') -or ${env:COMPUTERNAME}.ToLower().StartsWith('yoga-')) {
        # terminate any running dsc process
        $dscpid = (Get-WmiObject msft_providers | ? {$_.provider -like 'dsccore'} | Select-Object -ExpandProperty HostProcessIdentifier)
        if ($dscpid) {
          Get-Process -Id $dscpid | Stop-Process -f
          Write-Log -message ('{0} :: dsc process with pid {1}, stopped.' -f $($MyInvocation.MyCommand.Name), $dscpid) -severity 'DEBUG'
        }
        foreach ($mof in @('Previous', 'backup', 'Current')) {
          if (Test-Path -Path ('{0}\System32\Configuration\{1}.mof' -f $env:SystemRoot, $mof) -ErrorAction SilentlyContinue) {
            Remove-Item -Path ('{0}\System32\Configuration\{1}.mof' -f $env:SystemRoot, $mof) -confirm:$false -force
            Write-Log -message ('{0}\System32\Configuration\{1}.mof deleted' -f $env:SystemRoot, $mof) -severity 'INFO'
          }
        }
      }
    }
    catch {
      Write-Log -message ('{0} :: failed to disable dsc: {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
    }
  }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
Run-MaintainSystem
