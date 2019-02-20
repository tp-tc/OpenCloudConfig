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
    Invoke-OccReset
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
      $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime })
      if ($all_task_paths.length -gt 1) {
        Write-Log -message ('{0} :: {1} task directories detected matching pattern: {2}' -f $($MyInvocation.MyCommand.Name), $all_task_paths.length, $target) -severity 'INFO'
        $old_task_paths = $all_task_paths[0..($all_task_paths.Length-2)]
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
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    try {
      if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w1064-')) {
        $guid = [Guid]::NewGuid()
        $scriptUrl = ('https://raw.githubusercontent.com/mozilla-releng/OpenCloudConfig/master/userdata/rundsc.ps1?{0}' -f $guid)
        $newScriptPath = ('C:\dsc\rundsc-{0}.ps1' -f $guid)
        (New-Object Net.WebClient).DownloadFile($scriptUrl, $newScriptPath)

        $oldScriptPath = 'C:\dsc\rundsc.ps1'
        if (Test-Path -Path $oldScriptPath -ErrorAction SilentlyContinue) {
          $newSha512Hash = (Get-FileHash -Path $newScriptPath -Algorithm 'SHA512').Hash
          $oldSha512Hash = (Get-FileHash -Path $oldScriptPath -Algorithm 'SHA512').Hash

          if ($newSha512Hash -ne $oldSha512Hash) {
            Write-Log -message ('{0} :: rundsc hashes do not match (old: {1}, new: {2})' -f $($MyInvocation.MyCommand.Name), ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'INFO'
            Remove-Item -Path $oldScriptPath -force -ErrorAction SilentlyContinue
            Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
          } else {
            Write-Log -message ('{0} :: rundsc hashes match (old: {1}, new: {2})' -f $($MyInvocation.MyCommand.Name), ('{0}...{1}' -f $oldSha512Hash.Substring(0, 9), $oldSha512Hash.Substring($oldSha512Hash.length - 9, 9)), ('{0}...{1}' -f $newSha512Hash.Substring(0, 9), $newSha512Hash.Substring($newSha512Hash.length - 9, 9))) -severity 'DEBUG'
            Remove-Item -Path $newScriptPath -force -ErrorAction SilentlyContinue
          }
        } else {
          Move-item -LiteralPath $newScriptPath -Destination $oldScriptPath
          Write-Log -message ('{0} :: existing rundsc not found. downloaded rundsc applied' -f $($MyInvocation.MyCommand.Name)) -severity 'INFO'
        }

        $gwConfigPath = 'C:\generic-worker\gen_worker.config'
        #$gwConfig = (Get-Content $gwConfigPath -raw | ConvertFrom-Json)
        $gwMasterConfigPath = 'C:\generic-worker\master-generic-worker.json'
        $gwExePath = 'C:\generic-worker\generic-worker.exe'
        if (Test-Path -Path $gwConfigPath -ErrorAction SilentlyContinue) {
          Write-Log -message ('{0} :: gw config found at {1}' -f $($MyInvocation.MyCommand.Name), $gwConfigPath) -severity 'DEBUG'
          if (Test-Path -Path $gwExePath -ErrorAction SilentlyContinue) {
            if (@(& $gwExePath @('--version') 2>&1) -like 'generic-worker 10.11.2 *') {
              Write-Log -message ('{0} :: gw 10.11.2 exe found at {1}' -f $($MyInvocation.MyCommand.Name), $gwExePath) -severity 'DEBUG'
              $cleanupSemaphorePath = 'C:\DSC\20190220-cleanup-complete.txt'
              if (-not (Test-Path -Path $cleanupSemaphorePath -ErrorAction SilentlyContinue)) {
                Remove-Item -Path $gwConfigPath -force -ErrorAction SilentlyContinue
                New-Item -Path $cleanupSemaphorePath -type file -force
                Write-Log -message ('{0} :: removed {1}' -f $($MyInvocation.MyCommand.Name), $gwConfigPath) -severity 'INFO'
              }
            } elseif (@(& $gwExePath @('--version') 2>&1) -like 'generic-worker 13.*') {
              Write-Log -message ('{0} :: gw 13+ exe found at {1}' -f $($MyInvocation.MyCommand.Name), $gwExePath) -severity 'DEBUG'
            }
          }
        } else {
          Write-Log -message ('{0} :: existing gw config not found' -f $($MyInvocation.MyCommand.Name)) -severity 'WARN'
        }
      }
    } catch {
      Write-Log -message ('{0} :: exception - {1}' -f $($MyInvocation.MyCommand.Name), $_.Exception.Message) -severity 'ERROR'
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
      if (${env:COMPUTERNAME}.ToLower().StartsWith('t-w1064-')) {
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
