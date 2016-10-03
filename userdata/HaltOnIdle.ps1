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

function Is-Running {
  param (
    [string] $proc,
    [bool] $predicate
  )
  if ($predicate) {
    Write-Log -message ('{0} :: {1} is running.' -f $($MyInvocation.MyCommand.Name), $proc) -severity 'INFO'
  } else {
    Write-Log -message ('{0} :: {1} is not running.' -f $($MyInvocation.MyCommand.Name), $proc) -severity 'WARN'
  }
  return $predicate
}

if (-not (Is-Running -proc 'generic-worker' -predicate (@(Get-Process | ? { $_.ProcessName -eq 'generic-worker' }).length -gt 0))) {
  if (-not (Is-Running -proc 'OpenCloudConfig' -predicate (Test-Path -Path 'C:\dsc\in-progress.lock' -ErrorAction SilentlyContinue))) {
    $uptime = (Get-Uptime)
    if (($uptime) -and ($uptime -gt (New-TimeSpan -minutes 5))) {
      Write-Log -message 'instance failed validity check and will be halted.' -severity 'ERROR'
      & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: instance failed validity checks', '-f', '-d', 'p:4:1')
    } else {
      Write-Log -message 'instance failed some validity checks and will be retested shortly.' -severity 'WARN'
    }
  } else {
    Write-Log -message 'instance appears to be initialising.' -severity 'INFO'
  }
} else {
  Write-Log -message 'instance appears to be productive.' -severity 'DEBUG'
}
if ([IO.Directory]::GetFiles('C:\log', '*.zip').Count -gt 5) {
  Write-Log -message 'instance appears to be boot-looping and will be halted.' -severity 'ERROR'
  & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: boot-loop detected', '-f', '-d', 'p:4:1')
}
