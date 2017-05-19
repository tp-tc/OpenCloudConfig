function Write-Log {
  param (
    [string] $message,
    [string] $severity = 'INFO',
    [string] $source = 'PrepLoaner',
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

function Remove-GenericWorker {
  $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  $autologonRegistryEntries = @{
    'DefaultUserName' = $winlogonPath;
    'DefaultPassword' = $winlogonPath;
    'AutoAdminLogon' = $winlogonPath
  }
  foreach ($name in $autologonRegistryEntries.Keys) {
    $path = $registryEntries.Item($name)
    $item = (Get-Item -Path $path)
    if (($item -ne $null) -and ($item.GetValue($name) -ne $null)) {
      Remove-ItemProperty -path $path -name $name
      Write-Log -message ('{0} :: registry entry: {1}\{2}, deleted.' -f $($MyInvocation.MyCommand.Name), $path, $name) -severity 'INFO'
    }
  }
  $gwuser = 'GenericWorker'
  if (@(Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq $gwuser }).length -gt 0) {
    Start-Process 'logoff' -ArgumentList @((((quser /server:. | ? { $_ -match $gwuser }) -split ' +')[2]), '/server:.') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-logoff.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $gwuser) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-logoff.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $gwuser)
    Start-Process 'net' -ArgumentList @('user', $gwuser, '/DELETE') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-{2}-delete.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $gwuser) -RedirectStandardError ('{0}\log\{1}.net-user-{2}-delete.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $gwuser)
    Write-Log -message ('{0} :: user: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), $gwuser) -severity 'INFO'
  }
  if (Test-Path -Path ('{0}\Users\{1}' -f $env:SystemDrive, $gwuser) -ErrorAction SilentlyContinue) {
    Remove-Item ('{0}\Users\{1}' -f $env:SystemDrive, $gwuser) -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
    Write-Log -message ('{0} :: path: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), ('{0}\Users\{1}' -f $env:SystemDrive, $gwuser)) -severity 'INFO'
  }
  if (Test-Path -Path ('{0}\Users\{1}*' -f $env:SystemDrive, $gwuser) -ErrorAction SilentlyContinue) {
    Remove-Item ('{0}\Users\{1}*' -f $env:SystemDrive, $gwuser) -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
    Write-Log -message ('{0} :: path: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), ('{0}\Users\{1}*' -f $env:SystemDrive, $gwuser)) -severity 'INFO'
  }
}

function Set-Credentials {
  param (
    [string] $username,
    [string] $password,
    [switch] $setautologon
  )
  begin {
    Write-Log -message ('{0} :: begin' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    try {
      & net @('user', $username, $password)
      Write-Log -message ('{0} :: credentials set for user: {1}.' -f $($MyInvocation.MyCommand.Name), $username) -severity 'INFO'
      if ($setautologon) {
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Type 'String' -Name 'DefaultPassword' -Value $password
        Write-Log -message ('{0} :: autologon set for user: {1}.' -f $($MyInvocation.MyCommand.Name), $username) -severity 'INFO'
      }
    }
    catch {
      Write-Log -message ('{0} :: failed to set credentials for user: {1}. {2}' -f $($MyInvocation.MyCommand.Name), $username, $_.Exception.Message) -severity 'ERROR'
    }
  }
  end {
    Write-Log -message ('{0} :: end' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
}

function Get-GeneratedPassword {
  param (
    [int] $length = 16
  )
  $chars=$null;
  for ($char = 48; $char -le 122; $char ++) {
    $chars += ,[char][byte]$char
  }
  $password = ''
  for ($i=1; $i -le $length; $i++) {
    $password += ($sourcedata | Get-Random)
  }
  return $password
}

$loanReqPath = 'Z:\loan-request.json'
$loanRegPath = 'HKLM:\SOFTWARE\OpenCloudConfig\Loan'

# exit if no loan request
if (-not (Test-Path -Path $loanReqPath -ErrorAction SilentlyContinue)) {
  Write-Log -message 'loaner semaphore not detected' -severity 'DEBUG'
  exit
}
# if reg keys exist, log activity and exit since an earlier run will have performed loan prep
if (Test-Path -Path $loanRegPath -ErrorAction SilentlyContinue) {
  if (@(Get-Process | ? { $_.ProcessName -eq 'rdpclip' }).length -gt 0) {
    # todo: record the ip address where the rdp session originates
    Write-Log -message 'rdp session detected on active loaner' -severity 'DEBUG'
  } else {
    Write-Log -message 'rdp session not detected on active loaner' -severity 'DEBUG'
  }
  exit
}

# create registry entries if file exists but reg entries don't
if ((Test-Path -Path $loanReqPath -ErrorAction SilentlyContinue) -and (-not (Test-Path -Path $loanRegPath -ErrorAction SilentlyContinue))) {
  New-Item -Path $loanRegPath -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Detected' -Value ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:sszzz')) -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Requested' -Value ((Get-Item -Path 'Z:\loan-requested.json').LastWriteTime) -Force | Out-Null
  $loanRequest = (Get-Content -Raw -Path $loanReqPath | ConvertFrom-Json)
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Email' -Value $loanRequest.requester.email -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'PublicKeyUrl' -Value $loanRequest.requester.publickeyurl -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'TaskId' -Value $loanRequest.requester.taskId -Force | Out-Null
}

if (-not (Test-Path -Path $loanRegPath -ErrorAction SilentlyContinue)) {
  exit
}

$loanRequestTime = (Get-Date -Date (Get-ItemProperty -Path $loanRegPath -Name 'Requested').Requested)
$loanRequestDetectedTime = (Get-Date -Date (Get-ItemProperty -Path $loanRegPath -Name 'Detected').Detected)
$loanRequestEmail = (Get-ItemProperty -Path $loanRegPath -Name 'Email').Email
$loanRequestPublicKeyUrl = (Get-ItemProperty -Path $loanRegPath -Name 'PublicKeyUrl').PublicKeyUrl
$loanRequestTaskFolder = (Get-ItemProperty -Path $loanRegPath -Name 'TaskFolder').TaskFolder
Write-Log -message ('loan request from {0} in task {1} ({2}) at {3} detected at {4}' -f $loanRequestEmail, $loanRequestTaskId, $loanRequestPublicKeyUrl, $loanRequestTime, $loanRequestDetectedTime) -severity 'INFO'

#New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Cleaned' -Value ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:sszzz')) -Force | Out-Null

$password = (Get-GeneratedPassword)
switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
  'Microsoft Windows 7*' {
    Set-Credentials -username 'root' -password $password
  }
  default {
    Set-Credentials -username 'Administrator' -password $password
  }
}
$password | Out-File -filePath ('{0}\credentials.txt' -f $env:Temp)

if ("${env:ProgramFiles(x86)}") {
  $gpg = ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)})
} else {
  $gpg = ('{0}\GNU\GnuPG\pub\gpg.exe' -f $env:ProgramFiles)
}

$artifactsPath = 'z:\loan'
if (-not (Test-Path $artifactsPath -ErrorAction SilentlyContinue)) {
  New-Item -Path $artifactsPath -ItemType directory -force
}
(New-Object Net.WebClient).DownloadFile($loanRequestPublicKeyUrl, ('{0}\public.key' -f $artifactsPath))
& $gpg @('--import', ('{0}\public.key' -f $artifactsPath)) | Out-File -filePath ('{0}\key-import.log' -f $artifactsPath)
& $gpg @('-e', '-u', 'releng-puppet-mail@mozilla.com', '-r', $loanRequestEmail, ('{0}\credentials.txt' -f $env:Temp)) | Out-File -filePath ('{0}\encryption.log' -f $artifactsPath)
Remove-Item -Path ('{0}\credentials.txt' -f $env:Temp) -f
Move-Item -Path ('{0}\credentials.txt.gpg' -f $env:Temp) -Destination $artifactsPath

# wait for $loanRequestTaskFolder to disapear, then delete the gw user
while ((Test-Path $loanRequestTaskFolder -ErrorAction SilentlyContinue)) { Start-Sleep 10 }
Remove-GenericWorker
