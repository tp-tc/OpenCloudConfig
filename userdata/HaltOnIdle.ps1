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

function Is-Terminating {
  try {
    $response = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/spot/termination-time')
  }
  catch {
    $response = $_.Exception.Message
  }
  if (-not ($response.Contains('(404)'))) {
    Write-Log -message ('{0} :: spot termination notice received: {1}.' -f $($MyInvocation.MyCommand.Name), $response) -severity 'WARN'
    return $true
  } else {
    Write-Log -message ('{0} :: spot termination notice not detected.' -f $($MyInvocation.MyCommand.Name), $proc) -severity 'DEBUG'
    return $false
  }
}

if (Is-Terminating) {
  exit
}
if (Test-Path -Path 'Z:\' -ErrorAction SilentlyContinue) {
  Write-Log -message 'drive z: exists' -severity 'DEBUG'
} else {
  Write-Log -message 'drive z: does not exist' -severity 'DEBUG'
}
$gwService = Get-Service -Name 'Generic Worker' -ErrorAction SilentlyContinue
if (-not (Is-Running -proc 'generic-worker' -predicate (@(Get-Process | ? { $_.ProcessName -eq 'generic-worker' }).length -gt 0) -or (($gwService) -and ($gwService.Status -eq 'Running')))) {
  if (-not (Is-Running -proc 'OpenCloudConfig' -predicate (Test-Path -Path 'C:\dsc\in-progress.lock' -ErrorAction SilentlyContinue))) {
    $uptime = (Get-Uptime)
    if (($uptime) -and ($uptime -gt (New-TimeSpan -minutes 5))) {

      if (@(Get-Process | ? { $_.ProcessName -eq 'rdpclip' }).length -eq 0) {
        Write-Log -message 'instance failed validity check and will be halted.' -severity 'ERROR'
        & shutdown @('-s', '-t', '0', '-c', 'HaltOnIdle :: instance failed validity checks', '-f', '-d', 'p:4:1')
      } else {
        Write-Log -message 'instance failed validity check and should be halted, but has rdp session in progress.' -severity 'DEBUG'
      }
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

if (Test-Path -Path 'y:\' -ErrorAction SilentlyContinue) {
  if (-not (Test-Path -Path 'y:\hg-shared' -ErrorAction SilentlyContinue)) {
    New-Item -Path 'y:\hg-shared' -ItemType directory -force
  }
  & icacls @('y:\hg-shared', '/grant', 'Everyone:(OI)(CI)F')
}