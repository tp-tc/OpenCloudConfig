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
    Set-TaskFirewallExceptions
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
function Set-TaskFirewallExceptions {
  param (
    [string] $target = $(if (Test-Path -Path 'Z:\' -ErrorAction SilentlyContinue) { 'Z:\task_*' } else { 'C:\Users\task_*' }),
    [hashtable] $childPaths = @{
      'ssltunnel' = 'build\tests\bin\ssltunnel.exe';
      'python' = 'build\venv\scripts\python.exe'
    }
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    $all_task_paths = @(Get-ChildItem -Path $target | Sort-Object -Property { $_.LastWriteTime } -Descending)
    if ($all_task_paths.Length) {
      $newest_task_path = $all_task_paths[0]
      foreach ($key in $childPaths.Keys) {
        $childPath = $childPaths.Item($key)
        $program = (Join-Path -Path $newest_task_path -ChildPath $childPath)
        foreach ($direction in @('in', 'out')) {
          $ruleName = ('task-{0}-{1}' -f $key, $direction)
          try {
            if ((Get-Command 'Get-NetFirewallRule' -ErrorAction 'SilentlyContinue') -and (Get-Command 'Set-NetFirewallRule' -ErrorAction 'SilentlyContinue') -and (Get-Command 'New-NetFirewallRule' -ErrorAction 'SilentlyContinue')) {
              if (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction 'SilentlyContinue') {
                Set-NetFirewallRule -DisplayName $ruleName -Program $program
                Write-Log -message ('{0} :: firewall rule: {1} updated with program: {2}' -f $($MyInvocation.MyCommand.Name), $ruleName, $program) -severity 'DEBUG'
              } else {
                New-NetFirewallRule -DisplayName $ruleName -Program $program -Direction ('{0}bound' -f $direction) -Action Allow
                Write-Log -message ('{0} :: firewall rule: {1} created with program: {2}' -f $($MyInvocation.MyCommand.Name), $ruleName, $program) -severity 'INFO'
              }
            } else {
              if ((& 'netsh.exe' @('advfirewall', 'firewall', 'show', 'rule', ('name={0}' -f $ruleName)))[1] -ne 'No rules match the specified criteria.') {
                & 'netsh.exe' @('advfirewall', 'firewall', 'set', 'rule', ('name={0}' -f $ruleName), ('program={0}' -f $program))
                Write-Log -message ('{0} :: firewall rule: {1} updated with program: {2}' -f $($MyInvocation.MyCommand.Name), $ruleName, $program) -severity 'DEBUG'
              } else {
                & 'netsh.exe' @('advfirewall', 'firewall', 'add', 'rule', ('name={0}' -f $ruleName), ('program={0}' -f $program), ('dir={0}' -f $direction), 'action=allow')
                Write-Log -message ('{0} :: firewall rule: {1} created with program: {2}' -f $($MyInvocation.MyCommand.Name), $ruleName, $program) -severity 'INFO'
              }
            }
          } catch {
            Write-Log -message ('{0} :: error setting firewall rule: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $ruleName, $_.Exception.Message) -severity 'ERROR'
          }
        }
      }
    } else {
      Write-Log -message ('{0} :: no task directories detected matching pattern: {1}' -f$($MyInvocation.MyCommand.Name), $target) -severity 'DEBUG'
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
