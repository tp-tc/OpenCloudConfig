function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'HaltOnIdle',
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
}

function Get-Uptime {
  if ($lastBoot = (Get-WmiObject win32_operatingsystem | select @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}).LastBootUpTime) {
    $uptime = ((Get-Date) - $lastBoot)
    Write-Log -message ('{0} :: last boot: {1}; uptime: {2:c}.' -f $($MyInvocation.MyCommand.Name), $lastBoot, $uptime) -severity 'INFO'
    return $uptime
  } else {
    Write-Log -message ('{0} :: failed to determine last boot.' -f $($MyInvocation.MyCommand.Name)) -severity 'WARN'
    return $false
  } 
}

function Is-ConditionTrue {
  param (
    [string] $proc,
    [bool] $predicate,
    [string] $activity = 'running',
    [string] $trueSeverity = 'INFO',
    [string] $falseSeverity = 'WARN'
  )
  if ($predicate) {
    Write-Log -message ('{0} :: {1} is {2}.' -f $($MyInvocation.MyCommand.Name), $proc, $activity) -severity $trueSeverity
  } else {
    Write-Log -message ('{0} :: {1} is not {2}.' -f $($MyInvocation.MyCommand.Name), $proc, $activity) -severity $falseSeverity
  }
  return $predicate
}

function Is-Terminating {
  try {
    $response = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/spot/termination-time')
    $result = (-not ($response.Contains('(404)')))
  }
  catch {
    $result = $false
  }
  if (($result) -and ($response)) {
    Write-Log -message ('{0} :: spot termination notice received: {1}.' -f $($MyInvocation.MyCommand.Name), $response) -severity 'WARN'
  } else {
    Write-Log -message ('{0} :: spot termination notice not detected.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  return [bool](($result) -and ($response))
}

function Is-OpenCloudConfigRunning {
  return (Is-ConditionTrue -proc 'OpenCloudConfig' -predicate (Test-Path -Path 'C:\dsc\in-progress.lock' -ErrorAction SilentlyContinue))
}

function Is-GenericWorkerRunning {
  return (Is-ConditionTrue -proc 'generic-worker' -predicate (@(Get-Process | ? { $_.ProcessName -eq 'generic-worker' }).length -gt 0))
}

function Is-RdpSessionActive {
  return (Is-ConditionTrue -proc 'remote desktop session' -predicate (@(Get-Process | ? { $_.ProcessName -eq 'rdpclip' }).length -gt 0) -activity 'active' -falseSeverity 'DEBUG')
}

function Is-DriveFormatInProgress {
  return (Is-ConditionTrue -proc 'drive format' -predicate (@(Get-Process | ? { $_.ProcessName -eq 'format.com' }).length -gt 0) -activity 'in progress' -falseSeverity 'DEBUG')
}

function Is-Loaner {
  return ((Test-Path -Path 'Z:\loan-request.json' -ErrorAction SilentlyContinue) -or (Test-Path -Path 'HKLM:\SOFTWARE\OpenCloudConfig\Loan' -ErrorAction SilentlyContinue))
}

function Is-ExplorerCrashingRepeatedly {
  return (Is-ConditionTrue -proc 'Explorer' -activity 'crashing repeatedy' -predicate (@(Get-EventLog -logName 'Application' -message '*Faulting application name: explorer.exe*' -newest 30 -ErrorAction SilentlyContinue).length -eq 30))
}

function Is-InstanceTwentyFourHoursOld {
  return (Is-ConditionTrue -proc 'launch time' -activity 'more than 24 hours ago' -predicate (([DateTime]::Now - @(Get-EventLog -logName 'Application' -source 'OpenCloudConfig' -message 'host renamed *' -newest 1)[0].TimeGenerated) -ge (New-TimeSpan -Hours 24)))
}

function Is-GenericWorkerIdle {
  return (Is-ConditionTrue -proc 'generic-worker' -activity 'idle more than 5 hours' -predicate (([DateTime]::Now - (Get-Item 'C:\generic-worker\generic-worker.log').LastWriteTime) -gt (New-TimeSpan -Hours 5)))
}

if (Is-Terminating) {
  exit
}
if (Test-Path -Path 'Z:\' -ErrorAction SilentlyContinue) {
  Write-Log -message 'drive z: exists' -severity 'DEBUG'
} else {
  Write-Log -message 'drive z: does not exist' -severity 'DEBUG'
}
if (-not (Is-Loaner)) {
  if (-not (Is-GenericWorkerRunning)) {
    if (-not (Is-OpenCloudConfigRunning)) {
      $uptime = (Get-Uptime)
      if (($uptime) -and ($uptime -gt (New-TimeSpan -minutes 5))) {
        if ((-not (Is-RdpSessionActive)) -and (-not (Is-DriveFormatInProgress))) {
          Write-Log -message ('instance failed productivity check and will be halted. uptime: {0}' -f $uptime) -severity 'ERROR'
          & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: instance failed productivity checks', '-f', '-d', 'p:4:1')
        } else {
          Write-Log -message 'instance failed productivity checks and would be halted, but has rdp session in progress or is formatting a drive.' -severity 'DEBUG'
        }
      } else {
        Write-Log -message 'instance failed productivity checks and will be retested shortly.' -severity 'WARN'
      }
    } else {
      if (Is-InstanceTwentyFourHoursOld) {
        Write-Log -message ('instance failed age check and will be halted. uptime: {0}' -f $uptime) -severity 'ERROR'
        & shutdown @('-s', '-t', '30', '-c', 'HaltOnIdle :: instance failed age check', '-d', 'p:4:1')
        exit
      }
      Write-Log -message 'instance appears to be initialising.' -severity 'INFO'
    }
  } else {
    if ((Is-GenericWorkerIdle) -or (Is-ExplorerCrashingRepeatedly)) {
      Write-Log -message ('instance failed reliability check and will be halted. uptime: {0}' -f $uptime) -severity 'ERROR'
      & shutdown @('-s', '-t', '30', '-c', 'HaltOnIdle :: instance failed reliability check', '-d', 'p:4:1')
      exit
    }
    Write-Log -message 'instance appears to be productive.' -severity 'DEBUG'
    $gwProcess = (Get-Process | ? { $_.ProcessName -eq 'generic-worker' })
    if (($gwProcess) -and ($gwProcess.PriorityClass) -and ($gwProcess.PriorityClass -ne [Diagnostics.ProcessPriorityClass]::AboveNormal)) {
      $priorityClass = $gwProcess.PriorityClass
      $gwProcess.PriorityClass = [Diagnostics.ProcessPriorityClass]::AboveNormal
      Write-Log -message ('process priority for generic worker altered from {0} to {1}.' -f $priorityClass, $gwProcess.PriorityClass) -severity 'INFO'
    }
  }
  if (Test-Path -Path 'y:\' -ErrorAction SilentlyContinue) {
    if (-not (Test-Path -Path 'y:\hg-shared' -ErrorAction SilentlyContinue)) {
      New-Item -Path 'y:\hg-shared' -ItemType directory -force
    }
    & icacls @('y:\hg-shared', '/grant', 'Everyone:(OI)(CI)F')
  }
} else {
  $loanerIdleTimeout = (New-TimeSpan -minutes 15)
  $loanerUnclaimedTimeout = (New-TimeSpan -minutes 30)

  $rdpSessionActiveMessages = @(Get-EventLog -logName 'Application' -source 'PrepLoaner' -message 'rdp session detected on active loaner' -ErrorAction SilentlyContinue)
  $rdpSessionInactiveMessages = @(Get-EventLog -logName 'Application' -source 'PrepLoaner' -message 'rdp session not detected on active loaner' -ErrorAction SilentlyContinue)
  $loanerStateUnknownMessages = @(Get-EventLog -logName 'Application' -source 'HaltOnIdle' -message 'loaner state unknown' -ErrorAction SilentlyContinue)

  if ($rdpSessionActiveMessages.length -gt 0) {
    $lastSessionActiveTimestamp = @($rdpSessionActiveMessages | Sort Index -Descending)[0].TimeGenerated
    $idleTime = ((Get-Date) - $lastSessionActiveTimestamp)
    if ($idleTime -gt $loanerIdleTimeout) {
      Write-Log -message ('last active session was {0:T}. loaner exceeded max idle time ({1:mm} minutes) and will be terminated.' -f $lastSessionActiveTimestamp, $loanerIdleTimeout) -severity 'INFO'
      & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: loaner exceeded max idle time', '-f', '-d', 'p:4:1')
    } else {
      Write-Log -message ('last active session was {0:T}. loaner within idle time ({1:mm} minutes) constraints.' -f $lastSessionActiveTimestamp, $loanerIdleTimeout) -severity 'INFO'
    }
  } elseif ($rdpSessionInactiveMessages.length -gt 0) {
    $provisionedTimestamp = @($rdpSessionInactiveMessages | Sort Index)[0].TimeGenerated
    $unclaimedTime = ((Get-Date) - $provisionedTimestamp)
    if ($unclaimedTime -gt $loanerUnclaimedTimeout) {
      Write-Log -message ('loaner provisioned at {0:T}. loaner exceeded max unclaimed time ({1:mm} minutes) and will be terminated.' -f $provisionedTimestamp, $loanerUnclaimedTimeout) -severity 'INFO'
      & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: loaner exceeded max unclaimed time', '-f', '-d', 'p:4:1')
    } else {
      Write-Log -message ('loaner provisioned at {0:T}. loaner within unclaimed time ({1:mm} minutes) constraints.' -f $provisionedTimestamp, $loanerUnclaimedTimeout) -severity 'INFO'
    }
  } elseif ($loanerStateUnknownMessages.length -gt 3) {
    $lastStateUnknownTimestamp = @($loanerStateUnknownMessages | Sort Index -Descending)[0].TimeGenerated
    Write-Log -message ('loaner state is unknown and has not been rectified since last check at {0:T}. instance will be terminated.' -f $lastStateUnknownTimestamp) -severity 'ERROR'
    & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: loaner state unknown and unrectified', '-f', '-d', 'p:4:1')
  } else {
    Write-Log -message 'loaner state unknown' -severity 'WARN'
  }
}
