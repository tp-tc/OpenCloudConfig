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

function Remove-Secrets {
  $paths = @(
    ('{0}\builds\crash-stats-api.token' -f $env:SystemDrive),
    ('{0}\builds\gapi.data' -f $env:SystemDrive),
    ('{0}\builds\google-oauth-api.key' -f $env:SystemDrive),
    ('{0}\builds\mozilla-api.key' -f $env:SystemDrive),
    ('{0}\builds\mozilla-desktop-geoloc-api.key' -f $env:SystemDrive),
    ('{0}\builds\mozilla-fennec-geoloc-api.key' -f $env:SystemDrive),
    ('{0}\builds\oauth' -f $env:SystemDrive),
    ('{0}\builds\occ-installers.tok' -f $env:SystemDrive),
    # intentionally commented (required for building firefox)
    #('{0}\builds\relengapi.tok' -f $env:SystemDrive),
    ('{0}\builds\tc-sccache.boto' -f $env:SystemDrive)
  )
  foreach ($path in $paths) {
    if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
      Remove-Item $path -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
      Write-Log -message ('{0} :: path: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), $path) -severity 'INFO'
    }
  }
}

function Remove-GenericWorker {
  $paths = @(
    ('{0}\generic-worker\disable-desktop-interrupt.reg' -f $env:SystemDrive),
    ('{0}\generic-worker\generic-worker.log' -f $env:SystemDrive),
    ('{0}\generic-worker\generic-worker.config' -f $env:SystemDrive),
    ('{0}\generic-worker\generic-worker-test-creds.cmd' -f $env:SystemDrive),
    ('{0}\generic-worker\livelog.crt' -f $env:SystemDrive),
    ('{0}\generic-worker\livelog.key' -f $env:SystemDrive),
    ('{0}\generic-worker\*.xml' -f $env:SystemDrive)
  )
  foreach ($path in $paths) {
    if (Test-Path -Path $path -ErrorAction SilentlyContinue) {
      Remove-Item $path -confirm:$false -recurse:$true -force -ErrorAction SilentlyContinue
      Write-Log -message ('{0} :: path: {1}, deleted.' -f $($MyInvocation.MyCommand.Name), $path) -severity 'INFO'
    }
  }
  $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
  $autologonRegistryEntries = @{
    'DefaultUserName' = $winlogonPath;
    'DefaultDomainName' = $winlogonPath;
    'DefaultPassword' = $winlogonPath;
    'AutoAdminLogon' = $winlogonPath
  }
  foreach ($name in $autologonRegistryEntries.Keys) {
    $path = $autologonRegistryEntries.Item($name)
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
    [string] $password
  )
  begin {
    Write-Log -message ('{0} :: begin' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
  }
  process {
    try {
      & net @('user', $username, $password)
      Write-Log -message ('{0} :: credentials set for user: {1}.' -f $($MyInvocation.MyCommand.Name), $username) -severity 'INFO'
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
  $rootPassword = ''
  for ($i=1; $i -le $length; $i++) {
    $rootPassword += ($chars | Get-Random)
  }
  return $rootPassword
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
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Requested' -Value ((Get-Item -Path $loanReqPath).LastWriteTime.ToString('yyyy-MM-ddTHH:mm:sszzz')) -Force | Out-Null
  $loanRequest = (Get-Content -Raw -Path $loanReqPath | ConvertFrom-Json)
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'Email' -Value $loanRequest.requester.email -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'PublicKeyUrl' -Value $loanRequest.requester.publickeyurl -Force | Out-Null
  New-ItemProperty -Path $loanRegPath -PropertyType String -Name 'TaskFolder' -Value $loanRequest.requester.taskFolder -Force | Out-Null
}

if (-not (Test-Path -Path $loanRegPath -ErrorAction SilentlyContinue)) {
  exit
}

$loanRequestTime = (Get-Date -Date (Get-ItemProperty -Path $loanRegPath -Name 'Requested').Requested)
$loanRequestDetectedTime = (Get-Date -Date (Get-ItemProperty -Path $loanRegPath -Name 'Detected').Detected)
$loanRequestEmail = (Get-ItemProperty -Path $loanRegPath -Name 'Email').Email
$loanRequestPublicKeyUrl = (Get-ItemProperty -Path $loanRegPath -Name 'PublicKeyUrl').PublicKeyUrl
$loanRequestTaskFolder = (Get-ItemProperty -Path $loanRegPath -Name 'TaskFolder').TaskFolder
Write-Log -message ('loan request from {0}/{1} ({2}) at {3} detected at {4}' -f $loanRequestEmail, $loanRequestPublicKeyUrl, $loanRequestTaskFolder, $loanRequestTime, $loanRequestDetectedTime) -severity 'INFO'
Remove-Secrets
switch -wildcard ((Get-WmiObject -class Win32_OperatingSystem).Caption) {
  'Microsoft Windows 7*' {
    $rootUsername = 'root'
  }
  default {
    $rootUsername = 'Administrator'
  }
}
$rootPassword = (Get-GeneratedPassword)
Set-Credentials -username $rootUsername -password $rootPassword
$workerUsername = 'GenericWorker'
$workerPassword = (Get-GeneratedPassword)
Set-Credentials -username $workerUsername -password $workerPassword

if ("${env:ProgramFiles(x86)}") {
  $gpg = ('{0}\GNU\GnuPG\pub\gpg.exe' -f ${env:ProgramFiles(x86)})
} else {
  $gpg = ('{0}\GNU\GnuPG\pub\gpg.exe' -f $env:ProgramFiles)
}

$artifactsPath = 'z:\loan'
if (-not (Test-Path $artifactsPath -ErrorAction SilentlyContinue)) {
  New-Item -Path $artifactsPath -ItemType directory -force
}
$token = [Guid]::NewGuid()
$publicIP = (New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/public-ipv4')
"host: $publicIP`n" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8'
"root username: $rootUsername`nroot password: $rootPassword`n" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8' -append
"worker username: $workerUsername`nworker password: $workerPassword`n" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8' -append
"`nremote desktop from Linux (en-US keyboard):`nxfreerdp /u:$rootUsername /p:'$rootPassword' /kbd:409 /w:1024 /h:768 +clipboard /v:$publicIP" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8' -append
"`nremote desktop from Linux (en-GB keyboard):`nxfreerdp /u:$rootUsername /p:'$rootPassword' /kbd:809 /w:1024 /h:768 +clipboard /v:$publicIP" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8' -append
"`nremote desktop from Windows:`nmstsc /w:1024 /h:768 /v:$publicIP" | Out-File -filePath ('{0}\{1}.txt' -f $env:Temp, $token) -Encoding 'UTF8' -append
(New-Object Net.WebClient).DownloadFile($loanRequestPublicKeyUrl, ('{0}\{1}.asc' -f $artifactsPath, $token))
$tempKeyring = ('{0}.gpg' -f $token)
Start-Process $gpg -ArgumentList @('--no-default-keyring', '--keyring', $tempKeyring, '--fingerprint') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\gpg-create-keyring.stdout.log' -f $artifactsPath) -RedirectStandardError ('{0}\gpg-create-keyring.stderr.log' -f $artifactsPath)
Start-Process $gpg -ArgumentList @('--no-default-keyring', '--keyring', $tempKeyring, '--import', ('{0}\{1}.asc' -f $artifactsPath, $token)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\gpg-import-key.stdout.log' -f $artifactsPath) -RedirectStandardError ('{0}\gpg-import-key.stderr.log' -f $artifactsPath)
Start-Process $gpg -ArgumentList @('--no-default-keyring', '--keyring', $tempKeyring, '--trust-model', 'always', '-e', '-u', 'releng-puppet-mail@mozilla.com', '-r', $loanRequestEmail, ('{0}\{1}.txt' -f $env:Temp, $token)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\gpg-encrypt.stdout.log' -f $artifactsPath) -RedirectStandardError ('{0}\gpg-encrypt.stderr.log' -f $artifactsPath)
Get-ChildItem -Path $artifactsPath | ? { !$_.PSIsContainer -and $_.Name.EndsWith('.log') -and $_.Length -eq 0 } | % { Remove-Item -Path $_.FullName -Force }
Remove-Item -Path ('{0}\{1}.txt' -f $env:Temp, $token) -force
Move-Item -Path ('{0}\{1}.txt.gpg' -f $env:Temp, $token) -Destination ('{0}\credentials.txt.gpg' -f $artifactsPath)
Write-Log -message 'credentials encrypted in task artefacts' -severity 'DEBUG'
Write-Log -message 'waiting for loan request task to complete' -severity 'DEBUG'
while ((Test-Path $loanRequestTaskFolder -ErrorAction SilentlyContinue)) {
  Start-Sleep 1
}
Write-Log -message 'loan request task completion detected' -severity 'DEBUG'
Remove-GenericWorker
